using Microsoft.Data.Sqlite;

namespace Orders.Api;

internal sealed class OrderTestSeams
{
    internal Func<Guid> UuidFactory { get; set; } = Guid.NewGuid;

    internal Action<SqliteConnection> BeforeBegin { get; set; } = static _ => { };

    internal Action<SqliteConnection, string> AfterOrderInsert { get; set; } = static (_, _) => { };

    internal Action<SqliteConnection, string> AfterItemsInsert { get; set; } = static (_, _) => { };

    internal Action<SqliteConnection, string> BeforeCommit { get; set; } = static (_, _) => { };

    internal Action<SqliteTransaction> CommitInvoker { get; set; } =
        static transaction => transaction.Commit();

    internal Action<SqliteConnection, string> AfterConfirmedCommit { get; set; } = static (_, _) => { };

    internal Action<string> PostCommitPreResponse { get; set; } = static _ => { };
}

internal sealed class SqliteOrderStore
{
    private const int CurrentSchemaVersion = 1;
    private readonly string _connectionString;
    private readonly SemaphoreSlim _writerGate;
    private readonly OrderTestSeams _seams;

    internal SqliteOrderStore(
        string databasePath,
        SemaphoreSlim writerGate,
        OrderTestSeams seams)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(databasePath);
        ArgumentNullException.ThrowIfNull(writerGate);
        ArgumentNullException.ThrowIfNull(seams);

        var fullPath = Path.GetFullPath(databasePath);
        var directory = Path.GetDirectoryName(fullPath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        _connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = fullPath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Private,
            ForeignKeys = true,
            Pooling = false
        }.ToString();
        _writerGate = writerGate;
        _seams = seams;
    }

    internal string ConnectionString => _connectionString;

    internal void Initialize()
    {
        using var connection = OpenConnection();

        var journalMode = ExecuteScalarString(connection, "PRAGMA journal_mode=WAL;");
        if (!string.Equals(journalMode, "wal", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("SQLite WAL mode could not be enabled.");
        }

        var version = ExecuteScalarInt64(connection, "PRAGMA user_version;");
        var applicationTables = ReadApplicationTables(connection);

        if (version == 0 && applicationTables.Count == 0)
        {
            CreateSchema(connection);
        }
        else if (version != CurrentSchemaVersion)
        {
            throw new InvalidOperationException("The SQLite schema version is incompatible.");
        }

        ValidateSchema(connection);
        ValidateIntegrity(connection);
    }

    internal async Task<Order> CreateAsync(
        ValidatedCreateOrder request,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(request);

        var gateAcquired = false;
        try
        {
            gateAcquired = await _writerGate
                .WaitAsync(TimeSpan.FromSeconds(1), cancellationToken)
                .ConfigureAwait(false);
            if (!gateAcquired)
            {
                throw new OrderTemporarilyUnavailableException("writer_gate_timeout");
            }

            try
            {
                using var connection = OpenConnection();
                for (var attempt = 1; attempt <= 3; attempt++)
                {
                    var orderId = _seams.UuidFactory().ToString("D");
                    SqliteTransaction? transaction = null;
                    var commitInvocationStarted = false;
                    var commitConfirmed = false;
                    try
                    {
                        _seams.BeforeBegin(connection);
                        transaction = connection.BeginTransaction(deferred: false);
                        InsertOrder(connection, transaction, orderId, request.CustomerId);
                        _seams.AfterOrderInsert(connection, orderId);
                        InsertItems(connection, transaction, orderId, request.Items);
                        _seams.AfterItemsInsert(connection, orderId);
                        _seams.BeforeCommit(connection, orderId);

                        commitInvocationStarted = true;
                        _seams.CommitInvoker(transaction);
                        commitConfirmed = true;
                        _seams.AfterConfirmedCommit(connection, orderId);

                        return new Order(orderId, request.CustomerId, request.Items);
                    }
                    catch (SqliteException exception)
                        when (!commitInvocationStarted && IsOrderIdCollision(exception))
                    {
                        RollbackKnownPreCommit(transaction);
                        if (attempt == 3)
                        {
                            throw new OrderUuidCollisionException(exception);
                        }
                    }
                    catch (Exception exception) when (commitInvocationStarted && !commitConfirmed)
                    {
                        throw new OrderCommitUncertainException(exception);
                    }
                    catch (Exception exception) when (commitConfirmed)
                    {
                        throw new OrderConfirmedPostCommitException(exception);
                    }
                    catch
                    {
                        RollbackKnownPreCommit(transaction);
                        throw;
                    }
                    finally
                    {
                        transaction?.Dispose();
                    }
                }

                throw new InvalidOperationException("The bounded UUID loop completed unexpectedly.");
            }
            catch (SqliteException exception) when (IsTemporarySqliteFailure(exception))
            {
                throw new OrderTemporarilyUnavailableException("sqlite_busy", exception);
            }
        }
        finally
        {
            if (gateAcquired)
            {
                _writerGate.Release();
            }
        }
    }

    internal Order? Get(string orderId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(orderId);

        try
        {
            using var connection = OpenConnection();
            using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT
                    orders.order_id,
                    orders.customer_id,
                    orders.status,
                    order_items.product_id,
                    order_items.quantity
                FROM orders
                INNER JOIN order_items ON order_items.order_id = orders.order_id
                WHERE orders.order_id = $orderId COLLATE BINARY
                ORDER BY order_items.rowid;
                """;
            command.Parameters.AddWithValue("$orderId", orderId);
            using var reader = command.ExecuteReader();
            if (!reader.Read())
            {
                return null;
            }

            var persistedOrderId = reader.GetString(0);
            var customerId = reader.GetString(1);
            var status = reader.GetString(2);
            var items = new List<OrderItem>();
            do
            {
                if (!string.Equals(reader.GetString(0), persistedOrderId, StringComparison.Ordinal)
                    || !string.Equals(reader.GetString(1), customerId, StringComparison.Ordinal)
                    || !string.Equals(reader.GetString(2), status, StringComparison.Ordinal))
                {
                    throw new InvalidOperationException("A query returned an inconsistent aggregate.");
                }

                items.Add(new OrderItem(reader.GetString(3), reader.GetInt64(4)));
            }
            while (reader.Read());

            return new Order(persistedOrderId, customerId, items, status);
        }
        catch (SqliteException exception) when (IsTemporarySqliteFailure(exception))
        {
            throw new OrderTemporarilyUnavailableException("sqlite_busy", exception);
        }
    }

    internal SqliteConnection OpenConnection()
    {
        var connection = new SqliteConnection(_connectionString);
        try
        {
            connection.Open();
            ExecuteNonQuery(connection, """
                PRAGMA foreign_keys=ON;
                PRAGMA busy_timeout=500;
                PRAGMA synchronous=FULL;
                """);

            if (ExecuteScalarInt64(connection, "PRAGMA foreign_keys;") != 1
                || ExecuteScalarInt64(connection, "PRAGMA busy_timeout;") != 500
                || ExecuteScalarInt64(connection, "PRAGMA synchronous;") != 2)
            {
                throw new InvalidOperationException("SQLite connection invariants could not be applied.");
            }

            return connection;
        }
        catch
        {
            connection.Dispose();
            throw;
        }
    }

    private static void CreateSchema(SqliteConnection connection)
    {
        using var transaction = connection.BeginTransaction(deferred: false);
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            CREATE TABLE orders (
                order_id TEXT COLLATE BINARY NOT NULL PRIMARY KEY,
                customer_id TEXT NOT NULL CHECK(length(customer_id) > 0),
                status TEXT NOT NULL CHECK(status = 'Pending')
            ) STRICT;

            CREATE TABLE order_items (
                order_id TEXT COLLATE BINARY NOT NULL,
                product_id TEXT COLLATE BINARY NOT NULL CHECK(length(product_id) > 0),
                quantity INTEGER NOT NULL CHECK(quantity > 0),
                PRIMARY KEY (order_id, product_id),
                FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE NO ACTION
            ) STRICT;

            PRAGMA user_version=1;
            """;
        command.ExecuteNonQuery();
        transaction.Commit();
    }

    private static void InsertOrder(
        SqliteConnection connection,
        SqliteTransaction transaction,
        string orderId,
        string customerId)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO orders(order_id, customer_id, status)
            VALUES ($orderId, $customerId, $status);
            """;
        command.Parameters.AddWithValue("$orderId", orderId);
        command.Parameters.AddWithValue("$customerId", customerId);
        command.Parameters.AddWithValue("$status", OrderStatuses.Pending);
        command.ExecuteNonQuery();
    }

    private static void InsertItems(
        SqliteConnection connection,
        SqliteTransaction transaction,
        string orderId,
        IReadOnlyList<OrderItem> items)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO order_items(order_id, product_id, quantity)
            VALUES ($orderId, $productId, $quantity);
            """;
        var orderIdParameter = command.Parameters.Add("$orderId", SqliteType.Text);
        var productIdParameter = command.Parameters.Add("$productId", SqliteType.Text);
        var quantityParameter = command.Parameters.Add("$quantity", SqliteType.Integer);
        orderIdParameter.Value = orderId;

        foreach (var item in items)
        {
            productIdParameter.Value = item.ProductId;
            quantityParameter.Value = item.Quantity;
            command.ExecuteNonQuery();
        }
    }

    private static bool IsOrderIdCollision(SqliteException exception) =>
        exception.SqliteErrorCode == 19
        && (exception.SqliteExtendedErrorCode == 1555
            || exception.SqliteExtendedErrorCode == 2067);

    private static bool IsTemporarySqliteFailure(SqliteException exception) =>
        exception.SqliteErrorCode is 5 or 6;

    private static void RollbackKnownPreCommit(SqliteTransaction? transaction)
    {
        if (transaction is null)
        {
            return;
        }

        try
        {
            transaction.Rollback();
        }
        catch (InvalidOperationException)
        {
            // The transaction is already inactive. The original failure remains authoritative.
        }
        catch (SqliteException)
        {
            // Rollback failure is handled as the original generic pre-commit failure.
        }
    }

    private static void ValidateSchema(SqliteConnection connection)
    {
        var version = ExecuteScalarInt64(connection, "PRAGMA user_version;");
        if (version != CurrentSchemaVersion)
        {
            throw new InvalidOperationException("The SQLite schema version is incompatible.");
        }

        var tables = ReadApplicationTables(connection);
        if (!tables.SetEquals(["order_items", "orders"]))
        {
            throw new InvalidOperationException("The SQLite schema contains an unexpected table set.");
        }

        ValidateColumns(
            connection,
            "orders",
            [
                new("order_id", "TEXT", true, 1),
                new("customer_id", "TEXT", true, 0),
                new("status", "TEXT", true, 0)
            ]);
        ValidateColumns(
            connection,
            "order_items",
            [
                new("order_id", "TEXT", true, 1),
                new("product_id", "TEXT", true, 2),
                new("quantity", "INTEGER", true, 0)
            ]);

        var ordersSql = ReadSchemaSql(connection, "orders");
        var itemsSql = ReadSchemaSql(connection, "order_items");
        var normalizedOrders = NormalizeSql(ordersSql);
        var normalizedItems = NormalizeSql(itemsSql);

        if (!normalizedOrders.Contains("STRICT", StringComparison.Ordinal)
            || !normalizedOrders.Contains("COLLATEBINARY", StringComparison.Ordinal)
            || !normalizedOrders.Contains("CHECK(LENGTH(CUSTOMER_ID)>0)", StringComparison.Ordinal)
            || !normalizedOrders.Contains("CHECK(STATUS='PENDING')", StringComparison.Ordinal)
            || !normalizedItems.Contains("STRICT", StringComparison.Ordinal)
            || !normalizedItems.Contains("COLLATEBINARY", StringComparison.Ordinal)
            || !normalizedItems.Contains("CHECK(LENGTH(PRODUCT_ID)>0)", StringComparison.Ordinal)
            || !normalizedItems.Contains("CHECK(QUANTITY>0)", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("The SQLite schema constraints are incompatible.");
        }

        using var foreignKeyCommand = connection.CreateCommand();
        foreignKeyCommand.CommandText = "PRAGMA foreign_key_list('order_items');";
        using var foreignKeyReader = foreignKeyCommand.ExecuteReader();
        if (!foreignKeyReader.Read()
            || !string.Equals(foreignKeyReader.GetString(2), "orders", StringComparison.Ordinal)
            || !string.Equals(foreignKeyReader.GetString(3), "order_id", StringComparison.Ordinal)
            || !string.Equals(foreignKeyReader.GetString(4), "order_id", StringComparison.Ordinal)
            || !string.Equals(foreignKeyReader.GetString(6), "NO ACTION", StringComparison.OrdinalIgnoreCase)
            || foreignKeyReader.Read())
        {
            throw new InvalidOperationException("The SQLite foreign key is incompatible.");
        }
    }

    private static void ValidateIntegrity(SqliteConnection connection)
    {
        if (!string.Equals(ExecuteScalarString(connection, "PRAGMA quick_check;"), "ok", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("SQLite quick_check failed.");
        }

        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA foreign_key_check;";
        using var reader = command.ExecuteReader();
        if (reader.Read())
        {
            throw new InvalidOperationException("SQLite foreign_key_check failed.");
        }
    }

    private static void ValidateColumns(
        SqliteConnection connection,
        string table,
        IReadOnlyList<ExpectedColumn> expected)
    {
        using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_xinfo('{table}');";
        using var reader = command.ExecuteReader();
        var actual = new List<ExpectedColumn>();
        while (reader.Read())
        {
            actual.Add(
                new ExpectedColumn(
                    reader.GetString(1),
                    reader.GetString(2),
                    reader.GetInt64(3) == 1,
                    checked((int)reader.GetInt64(5))));
        }

        if (!actual.SequenceEqual(expected))
        {
            throw new InvalidOperationException($"The SQLite {table} columns are incompatible.");
        }
    }

    private static HashSet<string> ReadApplicationTables(SqliteConnection connection)
    {
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT name
            FROM sqlite_schema
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%';
            """;
        using var reader = command.ExecuteReader();
        var tables = new HashSet<string>(StringComparer.Ordinal);
        while (reader.Read())
        {
            tables.Add(reader.GetString(0));
        }

        return tables;
    }

    private static string ReadSchemaSql(SqliteConnection connection, string table)
    {
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = $name;";
        command.Parameters.AddWithValue("$name", table);
        return command.ExecuteScalar() as string
            ?? throw new InvalidOperationException($"Missing SQLite schema for {table}.");
    }

    private static string NormalizeSql(string sql) =>
        string.Concat(sql.Where(character => !char.IsWhiteSpace(character))).ToUpperInvariant();

    private static void ExecuteNonQuery(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private static long ExecuteScalarInt64(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt64(command.ExecuteScalar(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static string ExecuteScalarString(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToString(command.ExecuteScalar(), System.Globalization.CultureInfo.InvariantCulture)
            ?? string.Empty;
    }

    private sealed record ExpectedColumn(string Name, string Type, bool NotNull, int PrimaryKeyOrder);
}

internal sealed class OrderTemporarilyUnavailableException(string category, Exception? inner = null)
    : Exception("The order store is temporarily unavailable.", inner)
{
    internal string Category { get; } = category;
}

internal sealed class OrderUuidCollisionException(Exception inner)
    : Exception("The UUID collision budget was exhausted.", inner);

internal sealed class OrderCommitUncertainException(Exception inner)
    : Exception("The commit outcome is uncertain.", inner);

internal sealed class OrderConfirmedPostCommitException(Exception inner)
    : Exception("A failure occurred after the order commit was confirmed.", inner);
