using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace Orders.Api.Tests;

[TestClass]
public sealed class LoadTests
{
    public TestContext TestContext { get; set; } = null!;

    [TestMethod]
    [TestCategory("Load")]
    public async Task Sc005_real_kestrel_25_users_500_operations_meets_strict_p95_gate()
    {
        using (var warmupStorage = TestStorage.Create())
        {
            await using var warmupFactory = new OrdersApiFactory(warmupStorage.DatabasePath);
            warmupFactory.UseKestrel(0);
            using var warmupClient = CreateKestrelClient(warmupFactory);
            var warmupSeeds = await SeedOrders(warmupClient, "load-warmup-seed");
            var warmup = await RunUsers(
                warmupClient,
                warmupSeeds,
                cycles: 2,
                prefix: "load-warmup");
            Assert.AreEqual(50, warmup.PostSent);
            Assert.AreEqual(150, warmup.GetSent);
            Assert.AreEqual(0, warmup.Unavailable503);
            Assert.AreEqual(0, warmup.Timeouts);
            Assert.AreEqual(0, warmup.Unexpected);
        }

        using var measurementStorage = TestStorage.Create();
        await using var measurementFactory = new OrdersApiFactory(measurementStorage.DatabasePath);
        measurementFactory.UseKestrel(0);
        using var measurementClient = CreateKestrelClient(measurementFactory);
        var seeds = await SeedOrders(measurementClient, "load-measurement-seed");

        var measured = await RunUsers(
            measurementClient,
            seeds,
            cycles: 5,
            prefix: "load-measured");

        Assert.AreEqual(125, measured.PostSent);
        Assert.AreEqual(375, measured.GetSent);
        Assert.AreEqual(125, measured.Success201);
        Assert.AreEqual(375, measured.Success200);
        Assert.AreEqual(0, measured.Unavailable503);
        Assert.AreEqual(0, measured.Timeouts);
        Assert.AreEqual(0, measured.Unexpected);
        Assert.AreEqual(125, measured.CreatedIds.Count);
        Assert.AreEqual(125, measured.CreatedIds.Distinct(StringComparer.Ordinal).Count());
        Assert.AreEqual(125, measured.ValidatedCreatedAggregates);
        Assert.AreEqual(500, measured.SuccessfulDurationsMs.Count);
        Assert.AreEqual(150L, AtomicityTests.CountRows(measurementStorage.DatabasePath, "orders"));
        Assert.AreEqual(275L, AtomicityTests.CountRows(measurementStorage.DatabasePath, "order_items"));

        var orderedDurations = measured.SuccessfulDurationsMs.Order().ToArray();
        var nearestRank = checked((int)Math.Ceiling(0.95 * orderedDurations.Length));
        var p95 = orderedDurations[nearestRank - 1];
        var environment =
            $"os={RuntimeInformation.OSDescription};cpu={Environment.GetEnvironmentVariable("PROCESSOR_IDENTIFIER") ?? $"{Environment.ProcessorCount} logical processors"};storage=local-temp-sqlite;runtime={RuntimeInformation.FrameworkDescription}";
        TestContext.WriteLine($"environment={environment}");
        TestContext.WriteLine("users=25 measured=500 post=125 get=375");
        TestContext.WriteLine(
            $"success201={measured.Success201} success200={measured.Success200} unavailable503={measured.Unavailable503} timeout={measured.Timeouts} unexpected={measured.Unexpected}");
        TestContext.WriteLine($"p95SuccessfulMs={p95:F3}");
        TestContext.WriteLine(
            $"result={(p95 < 2_000 && measured.Unavailable503 == 0 && measured.Timeouts == 0 && measured.Unexpected == 0 ? "PASS" : "FAIL")}");

        Assert.IsTrue(
            p95 < 2_000,
            $"SC-005 requires p95 < 2000 ms; actual p95 was {p95:F3} ms.");
    }

    private static HttpClient CreateKestrelClient(OrdersApiFactory factory)
    {
        var client = factory.CreateClient(
            new WebApplicationFactoryClientOptions
            {
                AllowAutoRedirect = false
            });
        var server = factory.Services.GetRequiredService<IServer>();
        var address = server.Features.Get<IServerAddressesFeature>()?.Addresses.Single()
            ?? throw new AssertFailedException("Kestrel did not publish one address.");
        client.BaseAddress = new Uri(address);
        client.Timeout = Timeout.InfiniteTimeSpan;
        return client;
    }

    private static async Task<string[]> SeedOrders(HttpClient client, string prefix)
    {
        var identifiers = new string[25];
        for (var index = 0; index < identifiers.Length; index++)
        {
            using var response = await client.PostAsJsonAsync(
                "/orders",
                new
                {
                    customerId = $"{prefix}-customer-{index:D2}",
                    items = new[]
                    {
                        new { productId = $"{prefix}-product-{index:D2}", quantity = 1L }
                    }
                });
            Assert.AreEqual(HttpStatusCode.Created, response.StatusCode);
            using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            identifiers[index] =
                body.RootElement.GetProperty("orderId").GetString()
                ?? throw new AssertFailedException("A seed order ID is required.");
        }

        return identifiers;
    }

    private static async Task<LoadResult> RunUsers(
        HttpClient client,
        IReadOnlyList<string> seedIds,
        int cycles,
        string prefix)
    {
        var result = new LoadResult();
        var barrier = new AsyncCycleBarrier(25);
        var users = Enumerable.Range(0, 25)
            .Select(
                user => RunUser(
                    client,
                    seedIds,
                    cycles,
                    prefix,
                    user,
                    barrier,
                    result))
            .ToArray();
        await Task.WhenAll(users);
        return result;
    }

    private static async Task RunUser(
        HttpClient client,
        IReadOnlyList<string> seedIds,
        int cycles,
        string prefix,
        int user,
        AsyncCycleBarrier barrier,
        LoadResult result)
    {
        for (var cycle = 0; cycle < cycles; cycle++)
        {
            await barrier.SignalAndWaitAsync();
            Interlocked.Increment(ref result.PostSent);
            var expectedItems = new ExpectedItems(
                $"{prefix}-product-A-{user:D2}-{cycle:D2}",
                $"{prefix}-product-B-{user:D2}-{cycle:D2}");
            var createRequest = new HttpRequestMessage(HttpMethod.Post, "/orders")
            {
                Content = JsonContent.Create(
                    new
                    {
                        customerId = $"{prefix}-customer-{user:D2}-{cycle:D2}",
                        items = new[]
                        {
                            new
                            {
                                productId = expectedItems.ProductA,
                                quantity = 1L
                            },
                            new
                            {
                                productId = expectedItems.ProductB,
                                quantity = 2L
                            }
                        }
                    })
            };
            var createdId = await SendCreate(client, createRequest, result);
            var ownId = createdId ?? seedIds[user];

            await SendGet(
                client,
                $"/orders/{ownId}",
                ownId,
                createdId is null ? null : expectedItems,
                result);
            await SendGet(
                client,
                $"/orders/{seedIds[(user + cycle) % seedIds.Count]}",
                seedIds[(user + cycle) % seedIds.Count],
                null,
                result);
            await SendGet(
                client,
                $"/orders/{seedIds[(user + cycle + 7) % seedIds.Count]}",
                seedIds[(user + cycle + 7) % seedIds.Count],
                null,
                result);
        }
    }

    private static async Task<string?> SendCreate(
        HttpClient client,
        HttpRequestMessage request,
        LoadResult result)
    {
        using (request)
        using (var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5)))
        {
            var timer = Stopwatch.StartNew();
            try
            {
                using var response = await client.SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    timeout.Token);
                var bytes = await response.Content.ReadAsByteArrayAsync(timeout.Token);
                timer.Stop();
                if (response.StatusCode == HttpStatusCode.Created)
                {
                    using var body = JsonDocument.Parse(bytes);
                    var root = body.RootElement;
                    var orderId = root.GetProperty("orderId").GetString();
                    if (orderId is null
                        || root.GetProperty("status").GetString() != "Pending")
                    {
                        Interlocked.Increment(ref result.Unexpected);
                        return null;
                    }

                    Interlocked.Increment(ref result.Success201);
                    result.SuccessfulDurationsMs.Add(timer.Elapsed.TotalMilliseconds);
                    result.CreatedIds.Add(orderId);
                    return orderId;
                }

                if (response.StatusCode == HttpStatusCode.ServiceUnavailable)
                {
                    Interlocked.Increment(ref result.Unavailable503);
                }
                else
                {
                    Interlocked.Increment(ref result.Unexpected);
                }
            }
            catch (OperationCanceledException) when (timeout.IsCancellationRequested)
            {
                timer.Stop();
                Interlocked.Increment(ref result.Timeouts);
            }
            catch (HttpRequestException)
            {
                timer.Stop();
                Interlocked.Increment(ref result.Unexpected);
            }
        }

        return null;
    }

    private static async Task SendGet(
        HttpClient client,
        string location,
        string expectedId,
        ExpectedItems? expectedItems,
        LoadResult result)
    {
        Interlocked.Increment(ref result.GetSent);
        using var request = new HttpRequestMessage(HttpMethod.Get, location);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        var timer = Stopwatch.StartNew();
        try
        {
            using var response = await client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                timeout.Token);
            var bytes = await response.Content.ReadAsByteArrayAsync(timeout.Token);
            timer.Stop();
            if (response.StatusCode == HttpStatusCode.OK)
            {
                try
                {
                    using var body = JsonDocument.Parse(bytes);
                    var root = body.RootElement;
                    if (!MatchesExpectedOrder(root, expectedId, expectedItems))
                    {
                        Interlocked.Increment(ref result.Unexpected);
                        return;
                    }
                }
                catch (JsonException)
                {
                    Interlocked.Increment(ref result.Unexpected);
                    return;
                }
                catch (InvalidOperationException)
                {
                    Interlocked.Increment(ref result.Unexpected);
                    return;
                }

                if (expectedItems is not null)
                {
                    Interlocked.Increment(ref result.ValidatedCreatedAggregates);
                }

                Interlocked.Increment(ref result.Success200);
                result.SuccessfulDurationsMs.Add(timer.Elapsed.TotalMilliseconds);
            }
            else if (response.StatusCode == HttpStatusCode.ServiceUnavailable)
            {
                Interlocked.Increment(ref result.Unavailable503);
            }
            else
            {
                Interlocked.Increment(ref result.Unexpected);
            }
        }
        catch (OperationCanceledException) when (timeout.IsCancellationRequested)
        {
            timer.Stop();
            Interlocked.Increment(ref result.Timeouts);
        }
        catch (HttpRequestException)
        {
            timer.Stop();
            Interlocked.Increment(ref result.Unexpected);
        }
    }

    private static bool MatchesExpectedOrder(
        JsonElement root,
        string expectedId,
        ExpectedItems? expectedItems)
    {
        if (root.ValueKind != JsonValueKind.Object
            || !root.TryGetProperty("orderId", out var orderId)
            || orderId.ValueKind != JsonValueKind.String
            || !string.Equals(orderId.GetString(), expectedId, StringComparison.Ordinal)
            || !root.TryGetProperty("status", out var status)
            || status.ValueKind != JsonValueKind.String
            || !string.Equals(status.GetString(), "Pending", StringComparison.Ordinal)
            || !root.TryGetProperty("items", out var items)
            || items.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        if (expectedItems is null)
        {
            return items.GetArrayLength() > 0;
        }

        if (items.GetArrayLength() != 2)
        {
            return false;
        }

        var productACount = 0;
        var productBCount = 0;
        foreach (var item in items.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object
                || !item.TryGetProperty("productId", out var productId)
                || productId.ValueKind != JsonValueKind.String
                || !item.TryGetProperty("quantity", out var quantity)
                || quantity.ValueKind != JsonValueKind.Number
                || !quantity.TryGetInt64(out var quantityValue))
            {
                return false;
            }

            var productIdValue = productId.GetString();
            if (string.Equals(productIdValue, expectedItems.ProductA, StringComparison.Ordinal)
                && quantityValue == 1)
            {
                productACount++;
            }
            else if (string.Equals(productIdValue, expectedItems.ProductB, StringComparison.Ordinal)
                     && quantityValue == 2)
            {
                productBCount++;
            }
            else
            {
                return false;
            }
        }

        return productACount == 1 && productBCount == 1;
    }

    private sealed record ExpectedItems(string ProductA, string ProductB);

    private sealed class LoadResult
    {
        internal readonly ConcurrentBag<double> SuccessfulDurationsMs = [];
        internal readonly ConcurrentBag<string> CreatedIds = [];
        internal int PostSent;
        internal int GetSent;
        internal int Success201;
        internal int Success200;
        internal int Unavailable503;
        internal int Timeouts;
        internal int Unexpected;
        internal int ValidatedCreatedAggregates;
    }

    private sealed class AsyncCycleBarrier
    {
        private readonly object _sync = new();
        private readonly int _participants;
        private int _remaining;
        private TaskCompletionSource _phase =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        internal AsyncCycleBarrier(int participants)
        {
            _participants = participants;
            _remaining = participants;
        }

        internal Task SignalAndWaitAsync()
        {
            lock (_sync)
            {
                var currentPhase = _phase;
                _remaining--;
                if (_remaining == 0)
                {
                    _remaining = _participants;
                    _phase = new TaskCompletionSource(
                        TaskCreationOptions.RunContinuationsAsynchronously);
                    currentPhase.SetResult();
                }

                return currentPhase.Task;
            }
        }
    }
}
