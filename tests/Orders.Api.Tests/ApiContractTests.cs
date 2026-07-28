using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;

namespace Orders.Api.Tests;

[TestClass]
public sealed partial class ApiContractTests
{
    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("US1")]
    public async Task Post_valid_orders_returns_closed_201_contract_and_new_uuid_each_time()
    {
        using var storage = TestStorage.Create();
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        using var client = factory.CreateClient();
        var request = new
        {
            customerId = "acceptance-unknown-customer",
            items = new object[]
            {
                new { productId = "acceptance-unknown-A", quantity = 1L },
                new { productId = "acceptance-unknown-B", quantity = long.MaxValue }
            }
        };
        var singleItemRequest = new
        {
            customerId = "acceptance-single-customer",
            items = new[]
            {
                new { productId = "acceptance-single-product", quantity = 1L }
            }
        };

        using var single = await client.PostAsJsonAsync("/orders", singleItemRequest);
        using var first = await client.PostAsJsonAsync("/orders", request);
        using var second = await client.PostAsJsonAsync("/orders", request);

        await AssertCreateResponse(single);
        await AssertCreateResponse(first);
        await AssertCreateResponse(second);
        var firstBody = JsonDocument.Parse(await first.Content.ReadAsStringAsync());
        var secondBody = JsonDocument.Parse(await second.Content.ReadAsStringAsync());
        var firstId = firstBody.RootElement.GetProperty("orderId").GetString();
        var secondId = secondBody.RootElement.GetProperty("orderId").GetString();
        Assert.IsNotNull(firstId);
        Assert.IsNotNull(secondId);
        Assert.AreNotEqual(firstId, secondId);
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("US2")]
    public async Task Get_returns_only_the_exact_seeded_complete_order_with_closed_200_contract()
    {
        using var storage = TestStorage.Create();
        var expectedId = Guid.NewGuid().ToString("D");
        var otherId = Guid.NewGuid().ToString("D");
        AtomicityTests.SeedOrder(
            storage.DatabasePath,
            expectedId,
            "acceptance-query-customer",
            [
                ("acceptance-query-product-A", 2L),
                ("acceptance-query-product-B", long.MaxValue)
            ]);
        AtomicityTests.SeedOrder(
            storage.DatabasePath,
            otherId,
            "acceptance-other-customer",
            [("acceptance-other-product", 9L)]);
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync($"/orders/{expectedId}");

        Assert.AreEqual(HttpStatusCode.OK, response.StatusCode);
        Assert.AreEqual("application/json", response.Content.Headers.ContentType?.MediaType);
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        CollectionAssert.AreEquivalent(
            new[] { "orderId", "customerId", "items", "status" },
            body.RootElement.EnumerateObject().Select(property => property.Name).ToArray());
        Assert.AreEqual(expectedId, body.RootElement.GetProperty("orderId").GetString());
        Assert.AreEqual(
            "acceptance-query-customer",
            body.RootElement.GetProperty("customerId").GetString());
        Assert.AreEqual("Pending", body.RootElement.GetProperty("status").GetString());

        var items = body.RootElement.GetProperty("items").EnumerateArray().ToArray();
        Assert.AreEqual(2, items.Length);
        foreach (var item in items)
        {
            CollectionAssert.AreEquivalent(
                new[] { "productId", "quantity" },
                item.EnumerateObject().Select(property => property.Name).ToArray());
        }

        CollectionAssert.AreEquivalent(
            new[]
            {
                ("acceptance-query-product-A", 2L),
                ("acceptance-query-product-B", long.MaxValue)
            },
            items.Select(
                    item => (
                        item.GetProperty("productId").GetString()!,
                        item.GetProperty("quantity").GetInt64()))
                .ToArray());
        Assert.IsFalse(
            (await response.Content.ReadAsStringAsync()).Contains(otherId, StringComparison.Ordinal));
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("JsonContract")]
    [TestCategory("US3")]
    public async Task Post_enforces_media_type_and_strict_body_matrix_without_persisting_invalid_input()
    {
        using var storage = TestStorage.Create();
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        using var client = factory.CreateClient();
        var invalidCases = new (string? Body, string? ContentType, bool AttachContent, HttpStatusCode Status, string Type)[]
        {
            (null, null, false, HttpStatusCode.UnsupportedMediaType, "urn:orders:problem:unsupported-media-type"),
            ("{", "text/plain", true, HttpStatusCode.UnsupportedMediaType, "urn:orders:problem:unsupported-media-type"),
            ("", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("null", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("[]", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":1,\"items\":[]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"c\",\"items\":{}}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"c\",\"items\":[{\"productId\":1,\"quantity\":1}]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"c\",\"items\":[{\"productId\":\"p\",\"quantity\":\"1\"}]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"c\",\"items\":[{\"productId\":\"p\",\"quantity\":9223372036854775808}]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"c\",\"items\":[{\"productId\":\"p\",\"quantity\":1.0}]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"c\",\"items\":[{\"productId\":\"p\",\"quantity\":1e0}]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"customerId\":\"a\",\"customerId\":\"b\",\"items\":[]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:invalid-body"),
            ("{\"CustomerId\":\"c\",\"Items\":[]}", "application/json", true, HttpStatusCode.BadRequest, "urn:orders:problem:validation")
        };

        foreach (var testCase in invalidCases)
        {
            using var request = BuildPost(testCase.Body, testCase.ContentType, testCase.AttachContent);
            using var response = await client.SendAsync(request);
            await AssertProblem(
                response,
                testCase.Status,
                testCase.Type,
                OrderProblems.OrdersInstance,
                testCase.Status == HttpStatusCode.BadRequest);
        }

        Assert.AreEqual(0L, AtomicityTests.CountRows(storage.DatabasePath, "orders"));
        Assert.AreEqual(0L, AtomicityTests.CountRows(storage.DatabasePath, "order_items"));
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("JsonContract")]
    [TestCategory("US3")]
    public async Task Post_accepts_json_parameters_ignores_unknown_properties_and_rejects_duplicates()
    {
        using var storage = TestStorage.Create();
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        using var client = factory.CreateClient();
        const string validWithUnknown = """
            {
              "customerId": "acceptance-json-customer",
              "items": [
                {
                  "productId": "acceptance-json-product",
                  "quantity": 1,
                  "ignoredItemValue": "synthetic"
                }
              ],
              "ignoredRequestValue": 42
            }
            """;

        using var validRequest = BuildPost(
            validWithUnknown,
            "application/json; charset=utf-8",
            attachContent: true);
        using var validResponse = await client.SendAsync(validRequest);
        Assert.AreEqual(HttpStatusCode.Created, validResponse.StatusCode);
        Assert.AreEqual(1L, AtomicityTests.CountRows(storage.DatabasePath, "orders"));

        const string duplicate = """
            {
              "customerId": "acceptance-duplicate-customer",
              "items": [
                { "productId": "acceptance-duplicate-product", "quantity": 1 },
                { "productId": "acceptance-duplicate-product", "quantity": 2 }
              ]
            }
            """;
        using var duplicateRequest = BuildPost(duplicate, "application/json", attachContent: true);
        using var duplicateResponse = await client.SendAsync(duplicateRequest);
        await AssertProblem(
            duplicateResponse,
            HttpStatusCode.BadRequest,
            "urn:orders:problem:validation",
            OrderProblems.OrdersInstance,
            hasErrors: true);
        using var duplicateBody = JsonDocument.Parse(await duplicateResponse.Content.ReadAsStringAsync());
        Assert.IsTrue(
            duplicateBody.RootElement.GetProperty("errors").TryGetProperty(
                "items[1].productId",
                out _));
        Assert.AreEqual(1L, AtomicityTests.CountRows(storage.DatabasePath, "orders"));
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("US3")]
    public async Task Query_errors_are_closed_safe_and_distinguish_missing_whitespace_and_unknown()
    {
        using var storage = TestStorage.Create();
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        using var client = factory.CreateClient();

        using var missing = await client.GetAsync("/orders");
        await AssertProblem(
            missing,
            HttpStatusCode.BadRequest,
            "urn:orders:problem:missing-order-id",
            OrderProblems.OrdersInstance,
            hasErrors: true);

        using var whitespace = await client.GetAsync("/orders/%20%20");
        await AssertProblem(
            whitespace,
            HttpStatusCode.BadRequest,
            "urn:orders:problem:validation",
            OrderProblems.OrderByIdInstance,
            hasErrors: true);

        using var unknown = await client.GetAsync("/orders/acceptance-unknown-order");
        await AssertProblem(
            unknown,
            HttpStatusCode.NotFound,
            "urn:orders:problem:not-found",
            OrderProblems.OrderByIdInstance,
            hasErrors: false);
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("US3")]
    public async Task Persistence_failures_return_closed_500_or_proven_precommit_503_without_leakage()
    {
        const string exceptionCanary = "exception-canary-must-not-leak";

        using (var unavailableStorage = TestStorage.Create())
        {
            var unavailableSeams = new OrderTestSeams();
            var previous = unavailableSeams.BeforeBegin;
            try
            {
                unavailableSeams.BeforeBegin =
                    _ => throw new OrderTemporarilyUnavailableException("storage_unavailable");
                await using var factory =
                    new OrdersApiFactory(unavailableStorage.DatabasePath, unavailableSeams);
                using var client = factory.CreateClient();
                using var response = await AtomicityTests.PostValid(client, "unavailable");
                await AssertProblem(
                    response,
                    HttpStatusCode.ServiceUnavailable,
                    "urn:orders:problem:temporarily-unavailable",
                    OrderProblems.OrdersInstance,
                    hasErrors: false);
                Assert.IsNull(response.Headers.RetryAfter);
            }
            finally
            {
                unavailableSeams.BeforeBegin = previous;
            }
        }

        using (var failureStorage = TestStorage.Create())
        {
            var failureSeams = new OrderTestSeams();
            var previous = failureSeams.BeforeCommit;
            try
            {
                failureSeams.BeforeCommit = (_, _) => throw new InvalidOperationException(exceptionCanary);
                await using var factory = new OrdersApiFactory(failureStorage.DatabasePath, failureSeams);
                using var client = factory.CreateClient();
                using var response = await AtomicityTests.PostValid(client, "failure");
                await AssertProblem(
                    response,
                    HttpStatusCode.InternalServerError,
                    "urn:orders:problem:internal",
                    OrderProblems.OrdersInstance,
                    hasErrors: false);
                var text = await response.Content.ReadAsStringAsync();
                Assert.IsFalse(text.Contains(exceptionCanary, StringComparison.Ordinal));
                Assert.IsFalse(text.Contains(failureStorage.DatabasePath, StringComparison.Ordinal));
                Assert.IsFalse(text.Contains("System.", StringComparison.Ordinal));
            }
            finally
            {
                failureSeams.BeforeCommit = previous;
            }
        }
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("OpenApi")]
    public void OpenApi_differential_audit_matches_the_three_runtime_operations_and_closed_schemas()
    {
        var contractPath = Path.Combine(
            FindRepositoryRoot(),
            "specs",
            "001-create-query-orders",
            "contracts",
            "openapi.yaml");
        var contract = File.ReadAllText(contractPath);
        Assert.AreEqual(
            2,
            Regex.Matches(contract, @"(?m)^  /orders(?:/\{orderId\})?:$").Count);
        Assert.AreEqual(3, Regex.Matches(contract, @"(?m)^    (?:post|get):$").Count);

        var postStart = contract.IndexOf("    post:", StringComparison.Ordinal);
        var missingGetStart = contract.IndexOf("    get:", postStart, StringComparison.Ordinal);
        var orderPathStart = contract.IndexOf("  /orders/{orderId}:", StringComparison.Ordinal);
        var orderGetStart = contract.IndexOf("    get:", orderPathStart, StringComparison.Ordinal);
        Assert.IsTrue(postStart >= 0 && missingGetStart > postStart);
        Assert.IsTrue(orderPathStart > missingGetStart && orderGetStart > orderPathStart);

        AssertStatusSet(
            contract[postStart..missingGetStart],
            "201",
            "400",
            "413",
            "415",
            "500",
            "503");
        AssertStatusSet(contract[missingGetStart..orderPathStart], "400", "500");
        AssertStatusSet(
            contract[orderGetStart..contract.IndexOf("components:", StringComparison.Ordinal)],
            "200",
            "400",
            "404",
            "500",
            "503");

        StringAssert.Contains(contract, "application/json:");
        StringAssert.Contains(contract, "application/problem+json:");
        StringAssert.Contains(contract, "Location:");
        Assert.IsFalse(Regex.IsMatch(contract, @"(?m)^\s+Retry-After:"));
        StringAssert.Contains(contract, "additionalProperties: true");
        Assert.IsTrue(
            Regex.Matches(contract, @"(?m)^\s+additionalProperties: false$").Count >= 5);
        StringAssert.Contains(contract, "required:\n        - orderId\n        - status");
        StringAssert.Contains(
            contract,
            "required:\n        - orderId\n        - customerId\n        - items\n        - status");
        StringAssert.Contains(contract, "x-idempotency: deliberately-not-supported");
        StringAssert.Contains(contract, "GET /orders nunca enumera");
        StringAssert.Contains(contract, "problemDetailsGuaranteed: false");
        StringAssert.Contains(contract, "host/router no asigne");
        StringAssert.Contains(contract, "propertyNames:");
        StringAssert.Contains(contract, "traceId");

        // Runtime evidence is deliberately split across the T016, T021 and T027
        // methods above; this audit adds only the static differential assertions.
    }

    [TestMethod]
    [TestCategory("Contract")]
    [TestCategory("HostBoundary")]
    public async Task Real_kestrel_enforces_one_mib_without_truncating_the_exact_large_valid_fixture()
    {
        const int targetValidBytes = 1_040_000;
        const int maximumBodyBytes = 1_048_576;
        const int itemCount = 12_000;
        using var storage = TestStorage.Create();
        await using var factory = new OrdersApiFactory(storage.DatabasePath);
        factory.UseKestrel(0);
        using var client = factory.CreateClient(
            new WebApplicationFactoryClientOptions
            {
                AllowAutoRedirect = false
            });
        var server = factory.Services.GetRequiredService<IServer>();
        var serverAddress = server.Features.Get<IServerAddressesFeature>()?.Addresses.Single()
            ?? throw new AssertFailedException("Kestrel did not publish one loopback address.");
        client.BaseAddress = new Uri(serverAddress);

        var productIds = Enumerable.Range(0, itemCount)
            .Select(index => $"acceptance-large-product-{index:D5}")
            .ToArray();
        var serializedItems = string.Join(
            ",",
            productIds.Select(
                productId =>
                    $"{{\"productId\":\"{productId}\",\"quantity\":1}}"));
        const string customerPrefix = "acceptance-large-customer-";
        var bodyWithoutPadding =
            $"{{\"customerId\":\"{customerPrefix}\",\"items\":[{serializedItems}]}}";
        var paddingLength =
            targetValidBytes - Encoding.UTF8.GetByteCount(bodyWithoutPadding);
        Assert.IsTrue(paddingLength > 0);
        var largeBody =
            $"{{\"customerId\":\"{customerPrefix}{new string('x', paddingLength)}\",\"items\":[{serializedItems}]}}";
        var largeBytes = Encoding.UTF8.GetBytes(largeBody);
        Assert.AreEqual(targetValidBytes, largeBytes.Length);

        using var validContent = new ByteArrayContent(largeBytes);
        validContent.Headers.ContentType = MediaTypeHeaderValue.Parse("application/json");
        using var validResponse = await client.PostAsync("/orders", validContent);
        Assert.AreEqual(HttpStatusCode.Created, validResponse.StatusCode);
        using var createdBody = JsonDocument.Parse(await validResponse.Content.ReadAsStringAsync());
        var location = validResponse.Headers.Location?.OriginalString;
        Assert.IsNotNull(location);
        using var query = await client.GetAsync(location);
        Assert.AreEqual(HttpStatusCode.OK, query.StatusCode);
        using (var queriedBody = JsonDocument.Parse(await query.Content.ReadAsStringAsync()))
        {
            var queriedItems = queriedBody.RootElement.GetProperty("items");
            Assert.AreEqual(itemCount, queriedItems.GetArrayLength());
            Assert.AreEqual(
                productIds[0],
                queriedItems[0].GetProperty("productId").GetString());
            Assert.AreEqual(
                productIds[^1],
                queriedItems[itemCount - 1].GetProperty("productId").GetString());
        }

        Assert.AreEqual(itemCount, CountItems(storage.DatabasePath, createdBody.RootElement.GetProperty("orderId").GetString()!));
        var baselineOrders = AtomicityTests.CountRows(storage.DatabasePath, "orders");
        var oversizedBytes = Encoding.UTF8.GetBytes(
            $"\"{new string('z', maximumBodyBytes)}\"");
        Assert.IsTrue(oversizedBytes.Length > maximumBodyBytes);

        using (var fixedLengthContent = new ByteArrayContent(oversizedBytes))
        {
            fixedLengthContent.Headers.ContentType = MediaTypeHeaderValue.Parse("application/json");
            using var oversizedResponse = await client.PostAsync("/orders", fixedLengthContent);
            Assert.AreEqual(HttpStatusCode.RequestEntityTooLarge, oversizedResponse.StatusCode);
        }

        Assert.AreEqual(baselineOrders, AtomicityTests.CountRows(storage.DatabasePath, "orders"));

        using (var chunkedRequest = new HttpRequestMessage(HttpMethod.Post, "/orders"))
        {
            chunkedRequest.Content = new ChunkedByteContent(oversizedBytes);
            chunkedRequest.Content.Headers.ContentType =
                MediaTypeHeaderValue.Parse("application/json");
            chunkedRequest.Headers.TransferEncodingChunked = true;
            using var chunkedResponse = await client.SendAsync(chunkedRequest);
            Assert.AreEqual(HttpStatusCode.RequestEntityTooLarge, chunkedResponse.StatusCode);
        }

        Assert.AreEqual(baselineOrders, AtomicityTests.CountRows(storage.DatabasePath, "orders"));

        var inconsistentResponse = await SendInconsistentLengthAsync(
            client.BaseAddress!,
            oversizedBytes);
        Assert.IsFalse(inconsistentResponse.Contains(" 201 ", StringComparison.Ordinal));
        Assert.AreEqual(baselineOrders, AtomicityTests.CountRows(storage.DatabasePath, "orders"));
    }

    private static async Task AssertCreateResponse(HttpResponseMessage response)
    {
        Assert.AreEqual(HttpStatusCode.Created, response.StatusCode);
        Assert.AreEqual("application/json", response.Content.Headers.ContentType?.MediaType);
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var properties = body.RootElement.EnumerateObject().Select(property => property.Name).ToArray();
        CollectionAssert.AreEquivalent(new[] { "orderId", "status" }, properties);
        Assert.AreEqual("Pending", body.RootElement.GetProperty("status").GetString());
        var orderId = body.RootElement.GetProperty("orderId").GetString();
        Assert.IsNotNull(orderId);
        Assert.IsTrue(CanonicalUuidV4Regex().IsMatch(orderId));
        Assert.IsTrue(Guid.TryParseExact(orderId, "D", out var parsed));
        Assert.AreEqual(4, parsed.Version);
        Assert.AreEqual($"/orders/{orderId}", response.Headers.Location?.OriginalString);
    }

    internal static async Task AssertProblem(
        HttpResponseMessage response,
        HttpStatusCode status,
        string type,
        string instance,
        bool hasErrors)
    {
        Assert.AreEqual(status, response.StatusCode);
        Assert.AreEqual("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.IsNull(response.Headers.RetryAfter);
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var expectedProperties = hasErrors
            ? new[] { "type", "title", "status", "detail", "instance", "traceId", "errors" }
            : new[] { "type", "title", "status", "detail", "instance", "traceId" };
        CollectionAssert.AreEquivalent(
            expectedProperties,
            body.RootElement.EnumerateObject().Select(property => property.Name).ToArray());
        Assert.AreEqual(type, body.RootElement.GetProperty("type").GetString());
        Assert.AreEqual((int)status, body.RootElement.GetProperty("status").GetInt32());
        Assert.AreEqual(instance, body.RootElement.GetProperty("instance").GetString());
        Assert.IsFalse(string.IsNullOrWhiteSpace(body.RootElement.GetProperty("title").GetString()));
        Assert.IsFalse(string.IsNullOrWhiteSpace(body.RootElement.GetProperty("detail").GetString()));
        Assert.IsFalse(string.IsNullOrWhiteSpace(body.RootElement.GetProperty("traceId").GetString()));
        if (hasErrors)
        {
            Assert.IsTrue(body.RootElement.GetProperty("errors").EnumerateObject().Any());
        }
    }

    private static HttpRequestMessage BuildPost(
        string? body,
        string? contentType,
        bool attachContent)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/orders");
        if (!attachContent)
        {
            return request;
        }

        request.Content = new ByteArrayContent(Encoding.UTF8.GetBytes(body ?? string.Empty));
        if (contentType is not null)
        {
            request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);
        }

        return request;
    }

    private static void AssertStatusSet(string operationYaml, params string[] expected)
    {
        var actual = Regex.Matches(operationYaml, @"(?m)^        '(\d{3})':")
            .Select(match => match.Groups[1].Value)
            .ToArray();
        CollectionAssert.AreEquivalent(expected, actual);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, "Orders.slnx")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("The repository root could not be located.");
    }

    private static int CountItems(string databasePath, string orderId)
    {
        using var connection = PersistenceTests.OpenRaw(databasePath);
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT count(*) FROM order_items WHERE order_id=$orderId;";
        command.Parameters.AddWithValue("$orderId", orderId);
        return checked((int)Convert.ToInt64(command.ExecuteScalar(), System.Globalization.CultureInfo.InvariantCulture));
    }

    private static async Task<string> SendInconsistentLengthAsync(
        Uri baseAddress,
        byte[] oversizedBody)
    {
        using var tcpClient = new TcpClient();
        await tcpClient.ConnectAsync(baseAddress.Host, baseAddress.Port);
        await using var stream = tcpClient.GetStream();
        var headers = Encoding.ASCII.GetBytes(
            $"POST /orders HTTP/1.1\r\nHost: {baseAddress.Host}:{baseAddress.Port}\r\nContent-Type: application/json\r\nContent-Length: 10\r\nConnection: close\r\n\r\n");
        await stream.WriteAsync(headers);
        try
        {
            await stream.WriteAsync(oversizedBody);
            await stream.FlushAsync();
        }
        catch (IOException)
        {
            // A protocol-level close is an acceptable rejection of inconsistent framing.
        }

        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        using var response = new MemoryStream();
        var buffer = new byte[4096];
        try
        {
            while (true)
            {
                var read = await stream.ReadAsync(buffer, cancellation.Token);
                if (read == 0)
                {
                    break;
                }

                response.Write(buffer, 0, read);
            }
        }
        catch (OperationCanceledException)
        {
            // The absence of a successful response still proves no creation bypass.
        }
        catch (IOException)
        {
            // The host may close the malformed connection without a complete response.
        }

        return Encoding.ASCII.GetString(response.ToArray());
    }

    [GeneratedRegex(
        "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        RegexOptions.CultureInvariant)]
    private static partial Regex CanonicalUuidV4Regex();
}

internal sealed class ChunkedByteContent(byte[] bytes) : HttpContent
{
    protected override Task SerializeToStreamAsync(
        Stream stream,
        TransportContext? context) =>
        stream.WriteAsync(bytes).AsTask();

    protected override bool TryComputeLength(out long length)
    {
        length = 0;
        return false;
    }
}
