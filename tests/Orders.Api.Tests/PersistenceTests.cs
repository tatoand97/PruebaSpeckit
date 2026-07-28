using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Orders.Api;

namespace Orders.Api.Tests;

[TestClass]
public sealed class PersistenceTests
{
    [TestMethod]
    [TestCategory("Persistence")]
    public void Initialize_creates_and_reuses_exact_schema_and_connection_invariants()
    {
        using var storage = TestStorage.Create();
        var store = CreateStore(storage.DatabasePath);

        store.Initialize();
        store.Initialize();

        using var connection = store.OpenConnection();
        Assert.AreEqual("wal", ScalarText(connection, "PRAGMA journal_mode;").ToLowerInvariant());
        Assert.AreEqual(1L, ScalarInt64(connection, "PRAGMA user_version;"));
        Assert.AreEqual(1L, ScalarInt64(connection, "PRAGMA foreign_keys;"));
        Assert.AreEqual(2L, ScalarInt64(connection, "PRAGMA synchronous;"));
        Assert.AreEqual(500L, ScalarInt64(connection, "PRAGMA busy_timeout;"));
        Assert.AreEqual("ok", ScalarText(connection, "PRAGMA quick_check;"));
        Assert.AreEqual(0L, RowCount(connection, "PRAGMA foreign_key_check;"));

        CollectionAssert.AreEqual(
            new[] { "order_items", "orders" },
            ReadStrings(
                connection,
                """
                SELECT name
                FROM sqlite_schema
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                ORDER BY name;
                """));

        var ordersSql = ScalarText(
            connection,
            "SELECT sql FROM sqlite_schema WHERE type='table' AND name='orders';");
        var itemsSql = ScalarText(
            connection,
            "SELECT sql FROM sqlite_schema WHERE type='table' AND name='order_items';");
        StringAssert.Contains(ordersSql, "STRICT");
        StringAssert.Contains(itemsSql, "STRICT");
        StringAssert.Contains(ordersSql, "COLLATE BINARY");
        StringAssert.Contains(itemsSql, "COLLATE BINARY");

        AssertColumns(
            connection,
            "orders",
            ("order_id", "TEXT", 1L, 1L),
            ("customer_id", "TEXT", 1L, 0L),
            ("status", "TEXT", 1L, 0L));
        AssertColumns(
            connection,
            "order_items",
            ("order_id", "TEXT", 1L, 1L),
            ("product_id", "TEXT", 1L, 2L),
            ("quantity", "INTEGER", 1L, 0L));
    }

    [TestMethod]
    [TestCategory("Persistence")]
    public void Initialize_fails_fast_for_incompatible_corrupt_and_unwritable_storage()
    {
        using var incompatible = TestStorage.Create();
        using (var connection = OpenRaw(incompatible.DatabasePath))
        {
            Execute(connection, "PRAGMA user_version=2;");
        }

        Assert.ThrowsExactly<InvalidOperationException>(
            () => CreateStore(incompatible.DatabasePath).Initialize());

        using var corrupt = TestStorage.Create();
        File.WriteAllBytes(corrupt.DatabasePath, [0x53, 0x51, 0x4c, 0x00, 0xff, 0x01]);
        Assert.Throws<SqliteException>(() => CreateStore(corrupt.DatabasePath).Initialize());

        using var directoryTarget = TestStorage.Create();
        Assert.Throws<SqliteException>(() => CreateStore(directoryTarget.DirectoryPath).Initialize());
    }

    [TestMethod]
    [TestCategory("Integration")]
    public async Task Host_requires_database_path_and_starts_with_valid_persistent_storage()
    {
        using var storage = TestStorage.Create();
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/not-an-endpoint");

        Assert.AreEqual(System.Net.HttpStatusCode.NotFound, response.StatusCode);
        Assert.IsTrue(File.Exists(storage.DatabasePath));
    }

    [TestMethod]
    [TestCategory("Persistence")]
    [TestCategory("US1")]
    public async Task Create_uses_one_dedicated_connection_and_persists_exact_complete_aggregate()
    {
        using var storage = TestStorage.Create();
        var seams = new OrderTestSeams();
        var observedConnections = new List<SqliteConnection>();
        var previousBeforeBegin = seams.BeforeBegin;
        var previousAfterOrder = seams.AfterOrderInsert;
        try
        {
            seams.BeforeBegin = connection => observedConnections.Add(connection);
            seams.AfterOrderInsert = (connection, _) => observedConnections.Add(connection);
            var store = new SqliteOrderStore(storage.DatabasePath, new SemaphoreSlim(1, 1), seams);
            store.Initialize();
            var request = new ValidatedCreateOrder(
                "  customer-\u00e9  ",
                [
                    new OrderItem("Product", 1),
                    new OrderItem("product ", long.MaxValue),
                    new OrderItem("e\u0301", 3)
                ]);

            var order = await store.CreateAsync(request, CancellationToken.None);

            Assert.AreEqual(2, observedConnections.Count);
            Assert.AreSame(observedConnections[0], observedConnections[1]);
            using var connection = store.OpenConnection();
            Assert.AreNotSame(observedConnections[0], connection);
            Assert.AreEqual(1L, ScalarInt64(connection, "SELECT count(*) FROM orders;"));
            Assert.AreEqual(3L, ScalarInt64(connection, "SELECT count(*) FROM order_items;"));
            Assert.AreEqual(
                "  customer-\u00e9  ",
                ScalarText(
                    connection,
                    $"SELECT customer_id FROM orders WHERE order_id='{order.OrderId}';"));

            using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT product_id, quantity
                FROM order_items
                WHERE order_id = $orderId
                ORDER BY rowid;
                """;
            command.Parameters.AddWithValue("$orderId", order.OrderId);
            using var reader = command.ExecuteReader();
            var items = new List<(string ProductId, long Quantity)>();
            while (reader.Read())
            {
                items.Add((reader.GetString(0), reader.GetInt64(1)));
            }

            CollectionAssert.AreEquivalent(
                new[]
                {
                    ("Product", 1L),
                    ("product ", long.MaxValue),
                    ("e\u0301", 3L)
                },
                items.ToArray());
        }
        finally
        {
            seams.BeforeBegin = previousBeforeBegin;
            seams.AfterOrderInsert = previousAfterOrder;
        }
    }

    [TestMethod]
    [TestCategory("Persistence")]
    [TestCategory("US2")]
    public void Query_is_binary_exact_complete_and_bypasses_the_writer_gate()
    {
        using var storage = TestStorage.Create();
        var firstId = Guid.NewGuid().ToString("D");
        var secondId = Guid.NewGuid().ToString("D");
        AtomicityTests.SeedOrder(
            storage.DatabasePath,
            firstId,
            " Customer ",
            [
                ("Product", 1L),
                ("product", 2L),
                ("\u00e9", 3L),
                ("e\u0301", 4L)
            ]);
        AtomicityTests.SeedOrder(
            storage.DatabasePath,
            secondId,
            "Other",
            [("Other", 5L)]);
        using var gate = new SemaphoreSlim(1, 1);
        var store = new SqliteOrderStore(storage.DatabasePath, gate, new OrderTestSeams());
        store.Initialize();
        Assert.IsTrue(gate.Wait(0));
        try
        {
            var order = store.Get(firstId);

            Assert.IsNotNull(order);
            Assert.AreEqual(firstId, order.OrderId);
            Assert.AreEqual(" Customer ", order.CustomerId);
            Assert.AreEqual("Pending", order.Status);
            CollectionAssert.AreEquivalent(
                new[]
                {
                    ("Product", 1L),
                    ("product", 2L),
                    ("\u00e9", 3L),
                    ("e\u0301", 4L)
                },
                order.Items.Select(item => (item.ProductId, item.Quantity)).ToArray());
            Assert.IsNull(store.Get(firstId.ToUpperInvariant()));
            Assert.IsNull(store.Get($" {firstId}"));
        }
        finally
        {
            gate.Release();
        }

        var connectionSettings = new SqliteConnectionStringBuilder(store.ConnectionString);
        Assert.AreEqual(SqliteCacheMode.Private, connectionSettings.Cache);
        Assert.IsFalse(connectionSettings.Pooling);
    }

    private static SqliteOrderStore CreateStore(string databasePath) =>
        new(databasePath, new SemaphoreSlim(1, 1), new OrderTestSeams());

    internal static SqliteConnection OpenRaw(string databasePath)
    {
        var connection = new SqliteConnection(
            new SqliteConnectionStringBuilder
            {
                DataSource = databasePath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString());
        connection.Open();
        return connection;
    }

    internal static void Execute(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    internal static long ScalarInt64(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt64(command.ExecuteScalar(), System.Globalization.CultureInfo.InvariantCulture);
    }

    internal static string ScalarText(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToString(command.ExecuteScalar(), System.Globalization.CultureInfo.InvariantCulture)
            ?? string.Empty;
    }

    internal static long RowCount(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        using var reader = command.ExecuteReader();
        long count = 0;
        while (reader.Read())
        {
            count++;
        }

        return count;
    }

    private static string[] ReadStrings(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        using var reader = command.ExecuteReader();
        var values = new List<string>();
        while (reader.Read())
        {
            values.Add(reader.GetString(0));
        }

        return values.ToArray();
    }

    private static void AssertColumns(
        SqliteConnection connection,
        string table,
        params (string Name, string Type, long NotNull, long PrimaryKeyOrder)[] expected)
    {
        using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_xinfo('{table}');";
        using var reader = command.ExecuteReader();
        var actual = new List<(string Name, string Type, long NotNull, long PrimaryKeyOrder)>();
        while (reader.Read())
        {
            actual.Add((reader.GetString(1), reader.GetString(2), reader.GetInt64(3), reader.GetInt64(5)));
        }

        CollectionAssert.AreEqual(expected, actual.ToArray());
    }
}

internal sealed class OrdersApiFactory : WebApplicationFactory<Program>
{
    private readonly OrderTestSeams? _seams;

    internal OrdersApiFactory(string databasePath, OrderTestSeams? seams = null)
    {
        DatabasePath = databasePath;
        _seams = seams;
    }

    internal string DatabasePath { get; }

    internal OrderTestSeams Seams =>
        _seams ?? Services.GetRequiredService<OrderTestSeams>();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("Orders:DatabasePath", DatabasePath);
        if (_seams is not null)
        {
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<OrderTestSeams>();
                services.AddSingleton(_seams);
            });
        }
    }
}

internal sealed class TestStorage : IDisposable
{
    private TestStorage(string directoryPath)
    {
        DirectoryPath = directoryPath;
        DatabasePath = Path.Combine(directoryPath, "orders.db");
    }

    internal string DirectoryPath { get; }

    internal string DatabasePath { get; }

    internal static TestStorage Create()
    {
        var directory = Path.Combine(
            Path.GetTempPath(),
            "Orders.Api.Tests",
            Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        return new TestStorage(directory);
    }

    public void Dispose()
    {
        if (Directory.Exists(DirectoryPath))
        {
            Directory.Delete(DirectoryPath, recursive: true);
        }
    }
}
