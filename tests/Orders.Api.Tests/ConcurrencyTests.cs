using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using Orders.Api;

namespace Orders.Api.Tests;

[TestClass]
public sealed class ConcurrencyTests
{
    [TestMethod]
    [TestCategory("Concurrency")]
    public async Task Writers_readers_timeouts_and_external_access_preserve_all_concurrency_guarantees()
    {
        using var storage = TestStorage.Create();
        var seams = new OrderTestSeams();
        var writerConnections = new ConcurrentBag<SqliteConnection>();
        var previousBeforeBegin = seams.BeforeBegin;
        var previousBeforeCommit = seams.BeforeCommit;
        var previousUuidFactory = seams.UuidFactory;
        var releaseBlockedWriter = new ManualResetEventSlim(initialState: false);
        var releaseSnapshotWriter = new ManualResetEventSlim(initialState: false);
        try
        {
            seams.BeforeBegin = connection => writerConnections.Add(connection);
            await using var factory = new OrdersApiFactory(storage.DatabasePath, seams);
            using var client = factory.CreateClient();

            using var ready = new CountdownEvent(25);
            using var release = new ManualResetEventSlim(initialState: false);
            var createTasks = Enumerable.Range(0, 25)
                .Select(
                    user => Task.Run(
                        async () =>
                        {
                            ready.Signal();
                            release.Wait();
                            using var response = await AtomicityTests.PostValid(
                                client,
                                $"concurrent-{user:D2}");
                            var body = await response.Content.ReadAsStringAsync();
                            return (response.StatusCode, Body: body);
                        }))
                .ToArray();

            Assert.IsTrue(ready.Wait(TimeSpan.FromSeconds(5)));
            release.Set();
            var creates = await Task.WhenAll(createTasks);
            Assert.IsTrue(creates.All(result => result.StatusCode == HttpStatusCode.Created));
            var identifiers = creates
                .Select(result => JsonDocument.Parse(result.Body))
                .Select(document =>
                {
                    using (document)
                    {
                        return document.RootElement.GetProperty("orderId").GetString()!;
                    }
                })
                .ToArray();
            Assert.AreEqual(25, identifiers.Distinct(StringComparer.Ordinal).Count());
            Assert.AreEqual(25L, AtomicityTests.CountRows(storage.DatabasePath, "orders"));
            Assert.AreEqual(25L, AtomicityTests.CountRows(storage.DatabasePath, "order_items"));
            Assert.AreEqual(25, writerConnections.Count);
            Assert.AreEqual(
                25,
                writerConnections.Distinct(ReferenceEqualityComparer.Instance).Count());

            var snapshotId = Guid.NewGuid();
            using var snapshotReached = new ManualResetEventSlim(initialState: false);
            seams.UuidFactory = () => snapshotId;
            seams.BeforeCommit = (_, _) =>
            {
                snapshotReached.Set();
                releaseSnapshotWriter.Wait();
            };
            var snapshotCreateTask = AtomicityTests.PostValid(client, "snapshot");
            Assert.IsTrue(snapshotReached.Wait(TimeSpan.FromSeconds(5)));

            using var beforeCommitRead = await client.GetAsync($"/orders/{snapshotId:D}");
            Assert.AreEqual(HttpStatusCode.NotFound, beforeCommitRead.StatusCode);
            releaseSnapshotWriter.Set();
            using var snapshotCreate = await snapshotCreateTask;
            Assert.AreEqual(HttpStatusCode.Created, snapshotCreate.StatusCode);
            using var afterCommitRead = await client.GetAsync($"/orders/{snapshotId:D}");
            Assert.AreEqual(HttpStatusCode.OK, afterCommitRead.StatusCode);
            using (var body = JsonDocument.Parse(await afterCommitRead.Content.ReadAsStringAsync()))
            {
                Assert.AreEqual(
                    "acceptance-product-snapshot",
                    body.RootElement.GetProperty("items")[0].GetProperty("productId").GetString());
            }

            seams.UuidFactory = previousUuidFactory;
            using var firstWriterReached = new ManualResetEventSlim(initialState: false);
            seams.BeforeCommit = (_, _) =>
            {
                firstWriterReached.Set();
                releaseBlockedWriter.Wait();
            };
            var blockedWriter = AtomicityTests.PostValid(client, "gate-holder");
            Assert.IsTrue(firstWriterReached.Wait(TimeSpan.FromSeconds(5)));
            var gateTimer = Stopwatch.StartNew();
            using var timedOutWriter = await AtomicityTests.PostValid(client, "gate-waiter");
            gateTimer.Stop();
            Assert.AreEqual(HttpStatusCode.ServiceUnavailable, timedOutWriter.StatusCode);
            Assert.IsTrue(gateTimer.Elapsed >= TimeSpan.FromMilliseconds(900));
            Assert.IsNull(timedOutWriter.Headers.RetryAfter);
            releaseBlockedWriter.Set();
            using var completedWriter = await blockedWriter;
            Assert.AreEqual(HttpStatusCode.Created, completedWriter.StatusCode);

            seams.BeforeCommit = previousBeforeCommit;
            using (var external = PersistenceTests.OpenRaw(storage.DatabasePath))
            {
                PersistenceTests.Execute(
                    external,
                    """
                    PRAGMA foreign_keys=ON;
                    PRAGMA busy_timeout=500;
                    """);
                using var lockTransaction = external.BeginTransaction(deferred: false);
                var busyTimer = Stopwatch.StartNew();
                using var busyResponse = await AtomicityTests.PostValid(client, "sqlite-busy");
                busyTimer.Stop();
                Assert.AreEqual(HttpStatusCode.ServiceUnavailable, busyResponse.StatusCode);
                Assert.IsTrue(busyTimer.Elapsed >= TimeSpan.FromMilliseconds(450));
                Assert.IsNull(busyResponse.Headers.RetryAfter);
                lockTransaction.Rollback();
            }

            var store = factory.Services.GetRequiredService<SqliteOrderStore>();
            var settings = new SqliteConnectionStringBuilder(store.ConnectionString);
            Assert.AreEqual(SqliteCacheMode.Private, settings.Cache);
            Assert.IsFalse(settings.Pooling);

            using (var external = store.OpenConnection())
            {
                using var duplicate = external.CreateCommand();
                duplicate.CommandText = """
                    INSERT INTO orders(order_id, customer_id, status)
                    VALUES ($orderId, 'acceptance-external-customer', 'Pending');
                    """;
                duplicate.Parameters.AddWithValue("$orderId", identifiers[0]);
                Assert.Throws<SqliteException>(() => duplicate.ExecuteNonQuery());

                using var orphan = external.CreateCommand();
                orphan.CommandText = """
                    INSERT INTO order_items(order_id, product_id, quantity)
                    VALUES ($orderId, 'acceptance-external-product', 1);
                    """;
                orphan.Parameters.AddWithValue("$orderId", Guid.NewGuid().ToString("D"));
                Assert.Throws<SqliteException>(() => orphan.ExecuteNonQuery());

                var rolledBackId = Guid.NewGuid().ToString("D");
                using (var transaction = external.BeginTransaction(deferred: false))
                {
                    using var insert = external.CreateCommand();
                    insert.Transaction = transaction;
                    insert.CommandText = """
                        INSERT INTO orders(order_id, customer_id, status)
                        VALUES ($orderId, 'acceptance-rollback-customer', 'Pending');
                        """;
                    insert.Parameters.AddWithValue("$orderId", rolledBackId);
                    insert.ExecuteNonQuery();
                    transaction.Rollback();
                }

                Assert.IsNull(store.Get(rolledBackId));
            }

            // SemaphoreSlim deliberately provides no FIFO guarantee; no ordering assertion is made.
        }
        finally
        {
            releaseSnapshotWriter.Set();
            releaseBlockedWriter.Set();
            seams.BeforeBegin = previousBeforeBegin;
            seams.BeforeCommit = previousBeforeCommit;
            seams.UuidFactory = previousUuidFactory;
            releaseBlockedWriter.Dispose();
            releaseSnapshotWriter.Dispose();
        }
    }
}
