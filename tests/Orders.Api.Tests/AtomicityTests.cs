using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using Orders.Api;

namespace Orders.Api.Tests;

[TestClass]
public sealed class AtomicityTests
{
    [TestMethod]
    [TestCategory("Atomicity")]
    [TestCategory("US1")]
    public async Task Commit_is_confirmed_before_201_and_production_defaults_are_functional()
    {
        using var storage = TestStorage.Create();
        var seams = new OrderTestSeams();
        var commitConfirmed = false;
        var previousAfterCommit = seams.AfterConfirmedCommit;
        var previousProgramSeam = seams.PostCommitPreResponse;
        try
        {
            seams.AfterConfirmedCommit = (_, _) => commitConfirmed = true;
            seams.PostCommitPreResponse = _ => Assert.IsTrue(commitConfirmed);
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();

            using var response = await PostValid(client);

            Assert.AreEqual(HttpStatusCode.Created, response.StatusCode);
            Assert.IsTrue(commitConfirmed);
            Assert.AreEqual(1L, CountRows(storage.DatabasePath, "orders"));
            Assert.AreEqual(1L, CountRows(storage.DatabasePath, "order_items"));
        }
        finally
        {
            seams.AfterConfirmedCommit = previousAfterCommit;
            seams.PostCommitPreResponse = previousProgramSeam;
        }

        using var defaultStorage = TestStorage.Create();
        await using var defaultFactory = new OrdersApiFactory(defaultStorage.DatabasePath);
        using var defaultClient = defaultFactory.CreateClient();
        using var defaultResponse = await PostValid(defaultClient);
        Assert.AreEqual(HttpStatusCode.Created, defaultResponse.StatusCode);
    }

    [TestMethod]
    [TestCategory("Atomicity")]
    [TestCategory("Identity")]
    [TestCategory("US1")]
    public async Task Uuid_collisions_retry_twice_then_succeed_without_partial_rows()
    {
        using var storage = TestStorage.Create();
        var existingId = Guid.NewGuid().ToString("D");
        var successfulId = Guid.NewGuid().ToString("D");
        SeedOrder(storage.DatabasePath, existingId);
        var seams = new OrderTestSeams();
        var identifiers = new Queue<Guid>(
            [Guid.Parse(existingId), Guid.Parse(existingId), Guid.Parse(successfulId)]);
        var previousFactory = seams.UuidFactory;
        try
        {
            seams.UuidFactory = () => identifiers.Dequeue();
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();

            using var response = await PostValid(client);
            using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

            Assert.AreEqual(HttpStatusCode.Created, response.StatusCode);
            Assert.AreEqual(successfulId, body.RootElement.GetProperty("orderId").GetString());
            Assert.AreEqual(2L, CountRows(storage.DatabasePath, "orders"));
            Assert.AreEqual(2L, CountRows(storage.DatabasePath, "order_items"));
        }
        finally
        {
            seams.UuidFactory = previousFactory;
        }
    }

    [TestMethod]
    [TestCategory("Atomicity")]
    [TestCategory("Identity")]
    [TestCategory("US1")]
    public async Task Third_uuid_collision_returns_safe_500_and_confirms_no_new_order()
    {
        using var storage = TestStorage.Create();
        var existingId = Guid.NewGuid().ToString("D");
        SeedOrder(storage.DatabasePath, existingId);
        var seams = new OrderTestSeams();
        var previousFactory = seams.UuidFactory;
        try
        {
            seams.UuidFactory = () => Guid.Parse(existingId);
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();

            using var response = await PostValid(client);
            var text = await response.Content.ReadAsStringAsync();

            Assert.AreEqual(HttpStatusCode.InternalServerError, response.StatusCode);
            StringAssert.Contains(text, "urn:orders:problem:internal");
            Assert.AreEqual(1L, CountRows(storage.DatabasePath, "orders"));
            Assert.AreEqual(1L, CountRows(storage.DatabasePath, "order_items"));
        }
        finally
        {
            seams.UuidFactory = previousFactory;
        }
    }

    [TestMethod]
    [TestCategory("Atomicity")]
    [TestCategory("US3")]
    public async Task Validation_gate_timeout_before_begin_and_cancellation_open_no_transaction()
    {
        using var storage = TestStorage.Create();
        var seams = new OrderTestSeams();
        var beginCount = 0;
        var previousBeforeBegin = seams.BeforeBegin;
        try
        {
            seams.BeforeBegin = _ => beginCount++;
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();

            using var invalid = await client.PostAsJsonAsync(
                "/orders",
                new { customerId = " ", items = Array.Empty<object>() });
            Assert.AreEqual(HttpStatusCode.BadRequest, invalid.StatusCode);
            Assert.AreEqual(0, beginCount);

            var gate = factory.Services.GetRequiredService<SemaphoreSlim>();
            Assert.IsTrue(await gate.WaitAsync(0));
            try
            {
                using var timeout = await PostValid(client, "gate-timeout");
                Assert.AreEqual(HttpStatusCode.ServiceUnavailable, timeout.StatusCode);
                Assert.AreEqual(0, beginCount);
                Assert.AreEqual(0L, CountRows(storage.DatabasePath, "orders"));
            }
            finally
            {
                gate.Release();
            }

            seams.BeforeBegin =
                _ => throw new OrderTemporarilyUnavailableException("storage_unavailable");
            using var beforeBeginFailure = await PostValid(client, "before-begin");
            Assert.AreEqual(HttpStatusCode.ServiceUnavailable, beforeBeginFailure.StatusCode);
            Assert.AreEqual(0L, CountRows(storage.DatabasePath, "orders"));
        }
        finally
        {
            seams.BeforeBegin = previousBeforeBegin;
        }

        using var cancelledStorage = TestStorage.Create();
        var cancelledSeams = new OrderTestSeams();
        var cancellationBeginCount = 0;
        var previousCancelledHook = cancelledSeams.BeforeBegin;
        try
        {
            cancelledSeams.BeforeBegin = _ => cancellationBeginCount++;
            var store = new SqliteOrderStore(
                cancelledStorage.DatabasePath,
                new SemaphoreSlim(1, 1),
                cancelledSeams);
            store.Initialize();
            using var cancellation = new CancellationTokenSource();
            cancellation.Cancel();
            try
            {
                await store.CreateAsync(
                    new ValidatedCreateOrder(
                        "acceptance-cancelled-customer",
                        [new OrderItem("acceptance-cancelled-product", 1)]),
                    cancellation.Token);
                Assert.Fail("A pre-acquisition cancellation must be observed.");
            }
            catch (OperationCanceledException)
            {
                Assert.AreEqual(0, cancellationBeginCount);
                Assert.AreEqual(0L, CountRows(cancelledStorage.DatabasePath, "orders"));
            }
        }
        finally
        {
            cancelledSeams.BeforeBegin = previousCancelledHook;
        }
    }

    [TestMethod]
    [TestCategory("Atomicity")]
    [TestCategory("US3")]
    public async Task Failures_after_order_after_items_and_before_commit_roll_back_completely()
    {
        await AssertPreCommitRollback(
            static seams =>
            {
                var previous = seams.AfterOrderInsert;
                seams.AfterOrderInsert = (_, _) => throw new InvalidOperationException("after-order");
                return () => seams.AfterOrderInsert = previous;
            },
            "after-order");
        await AssertPreCommitRollback(
            static seams =>
            {
                var previous = seams.AfterItemsInsert;
                seams.AfterItemsInsert = (_, _) => throw new InvalidOperationException("after-items");
                return () => seams.AfterItemsInsert = previous;
            },
            "after-items");

        using var storage = TestStorage.Create();
        var seams = new OrderTestSeams();
        var commitInvoked = false;
        var previousBeforeCommit = seams.BeforeCommit;
        var previousCommitInvoker = seams.CommitInvoker;
        try
        {
            seams.BeforeCommit = (_, _) => throw new InvalidOperationException("before-commit");
            seams.CommitInvoker = transaction =>
            {
                commitInvoked = true;
                transaction.Commit();
            };
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();

            using var response = await PostValid(client, "before-commit");

            Assert.AreEqual(HttpStatusCode.InternalServerError, response.StatusCode);
            Assert.IsFalse(commitInvoked);
            Assert.AreEqual(0L, CountRows(storage.DatabasePath, "orders"));
            Assert.AreEqual(0L, CountRows(storage.DatabasePath, "order_items"));
        }
        finally
        {
            seams.BeforeCommit = previousBeforeCommit;
            seams.CommitInvoker = previousCommitInvoker;
        }
    }

    [TestMethod]
    [TestCategory("Atomicity")]
    [TestCategory("US3")]
    public async Task Uncertain_and_confirmed_postcommit_failures_never_rollback_or_return_503()
    {
        using (var uncertainStorage = TestStorage.Create())
        {
            var seams = new OrderTestSeams();
            var previous = seams.CommitInvoker;
            try
            {
                seams.CommitInvoker = transaction =>
                {
                    transaction.Commit();
                    throw new InvalidOperationException("uncertain-after-real-commit");
                };
                await using var factory = new OrdersApiFactory(uncertainStorage.DatabasePath, seams);
                using var client = factory.CreateClient();
                using var response = await PostValid(client, "uncertain");

                Assert.AreEqual(HttpStatusCode.InternalServerError, response.StatusCode);
                Assert.AreNotEqual(HttpStatusCode.ServiceUnavailable, response.StatusCode);
                Assert.AreEqual(1L, CountRows(uncertainStorage.DatabasePath, "orders"));
                Assert.AreEqual(1L, CountRows(uncertainStorage.DatabasePath, "order_items"));
            }
            finally
            {
                seams.CommitInvoker = previous;
            }
        }

        using (var afterCommitStorage = TestStorage.Create())
        {
            var seams = new OrderTestSeams();
            var previous = seams.AfterConfirmedCommit;
            try
            {
                seams.AfterConfirmedCommit = (_, _) => throw new InvalidOperationException("after-commit");
                await using var factory = new OrdersApiFactory(afterCommitStorage.DatabasePath, seams);
                using var client = factory.CreateClient();
                using var response = await PostValid(client, "after-commit");

                Assert.AreEqual(HttpStatusCode.InternalServerError, response.StatusCode);
                Assert.AreNotEqual(HttpStatusCode.ServiceUnavailable, response.StatusCode);
                Assert.AreEqual(1L, CountRows(afterCommitStorage.DatabasePath, "orders"));
                Assert.AreEqual(1L, CountRows(afterCommitStorage.DatabasePath, "order_items"));
            }
            finally
            {
                seams.AfterConfirmedCommit = previous;
            }
        }

        using (var programStorage = TestStorage.Create())
        {
            var seams = new OrderTestSeams();
            var previous = seams.PostCommitPreResponse;
            try
            {
                seams.PostCommitPreResponse = _ => throw new InvalidOperationException("program-post-commit");
                await using var factory = new OrdersApiFactory(programStorage.DatabasePath, seams);
                using var client = factory.CreateClient();
                using var response = await PostValid(client, "program-post-commit");

                Assert.AreEqual(HttpStatusCode.InternalServerError, response.StatusCode);
                Assert.AreNotEqual(HttpStatusCode.ServiceUnavailable, response.StatusCode);
                Assert.AreEqual(1L, CountRows(programStorage.DatabasePath, "orders"));
                Assert.AreEqual(1L, CountRows(programStorage.DatabasePath, "order_items"));
            }
            finally
            {
                seams.PostCommitPreResponse = previous;
            }
        }
    }

    internal static Task<HttpResponseMessage> PostValid(HttpClient client, string suffix = "001") =>
        client.PostAsJsonAsync(
            "/orders",
            new
            {
                customerId = $"acceptance-customer-{suffix}",
                items = new[]
                {
                    new { productId = $"acceptance-product-{suffix}", quantity = 1L }
                }
            });

    internal static long CountRows(string databasePath, string table)
    {
        using var connection = PersistenceTests.OpenRaw(databasePath);
        return PersistenceTests.ScalarInt64(connection, $"SELECT count(*) FROM {table};");
    }

    internal static void SeedOrder(
        string databasePath,
        string orderId,
        string customerId = "acceptance-seed-customer",
        IReadOnlyList<(string ProductId, long Quantity)>? items = null)
    {
        items ??= [("acceptance-seed-product", 1L)];
        var store = new SqliteOrderStore(
            databasePath,
            new SemaphoreSlim(1, 1),
            new OrderTestSeams());
        store.Initialize();
        using var connection = store.OpenConnection();
        using var transaction = connection.BeginTransaction();
        using var orderCommand = connection.CreateCommand();
        orderCommand.Transaction = transaction;
        orderCommand.CommandText = """
            INSERT INTO orders(order_id, customer_id, status)
            VALUES ($orderId, $customerId, 'Pending');
            """;
        orderCommand.Parameters.AddWithValue("$orderId", orderId);
        orderCommand.Parameters.AddWithValue("$customerId", customerId);
        orderCommand.ExecuteNonQuery();
        using var itemCommand = connection.CreateCommand();
        itemCommand.Transaction = transaction;
        itemCommand.CommandText = """
            INSERT INTO order_items(order_id, product_id, quantity)
            VALUES ($orderId, $productId, $quantity);
            """;
        var orderIdParameter = itemCommand.Parameters.Add("$orderId", SqliteType.Text);
        var productIdParameter = itemCommand.Parameters.Add("$productId", SqliteType.Text);
        var quantityParameter = itemCommand.Parameters.Add("$quantity", SqliteType.Integer);
        orderIdParameter.Value = orderId;
        foreach (var item in items)
        {
            productIdParameter.Value = item.ProductId;
            quantityParameter.Value = item.Quantity;
            itemCommand.ExecuteNonQuery();
        }

        transaction.Commit();
    }

    private static async Task AssertPreCommitRollback(
        Func<OrderTestSeams, Action> configure,
        string suffix)
    {
        using var storage = TestStorage.Create();
        var seams = new OrderTestSeams();
        var restore = configure(seams);
        try
        {
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();
            using var response = await PostValid(client, suffix);

            Assert.AreEqual(HttpStatusCode.InternalServerError, response.StatusCode);
            Assert.AreEqual(0L, CountRows(storage.DatabasePath, "orders"));
            Assert.AreEqual(0L, CountRows(storage.DatabasePath, "order_items"));
        }
        finally
        {
            restore();
        }
    }
}
