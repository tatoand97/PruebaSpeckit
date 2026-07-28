using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

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

    [GeneratedRegex(
        "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        RegexOptions.CultureInvariant)]
    private static partial Regex CanonicalUuidV4Regex();
}
