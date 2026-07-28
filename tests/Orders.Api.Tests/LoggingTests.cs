using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using Orders.Api;

namespace Orders.Api.Tests;

[TestClass]
public sealed partial class LoggingTests
{
    [TestMethod]
    [TestCategory("Logging")]
    [TestCategory("Security")]
    public async Task Native_json_console_logs_only_the_closed_safe_state_and_correlate_problem_trace_id()
    {
        const string customerCanary = "security-synthetic-customer-canary";
        const string productCanary = "security-synthetic-product-canary";
        const string routeCanary = "security-synthetic-route-canary";
        const string headerCanary = "security-synthetic-header-canary";
        const string exceptionCanary = "security-synthetic-exception-canary";
        const string databasePathCanary = "security-synthetic-db-path-canary";
        var directory = Path.Combine(
            Path.GetTempPath(),
            "Orders.Api.Tests",
            databasePathCanary,
            Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        var databasePath = Path.Combine(directory, "orders.db");
        var seams = new OrderTestSeams();
        var previousBeforeBegin = seams.BeforeBegin;
        var previousBeforeCommit = seams.BeforeCommit;
        var originalOut = Console.Out;
        var buffer = new StringWriter(CultureInfo.InvariantCulture);
        var synchronizedWriter = TextWriter.Synchronized(buffer);
        string validationTraceId;
        try
        {
            Console.SetOut(synchronizedWriter);
            await using (var factory = new OrdersApiFactory(databasePath, seams))
            {
                using var client = factory.CreateClient();
                using var validRequest = new HttpRequestMessage(HttpMethod.Post, "/orders")
                {
                    Content = JsonContent.Create(
                        new
                        {
                            customerId = customerCanary,
                            items = new[]
                            {
                                new { productId = productCanary, quantity = 1L }
                            }
                        })
                };
                validRequest.Headers.Add("X-Synthetic-Canary", headerCanary);
                using var created = await client.SendAsync(validRequest);
                Assert.AreEqual(HttpStatusCode.Created, created.StatusCode);
                var location = created.Headers.Location?.OriginalString
                    ?? throw new AssertFailedException("Location is required.");
                var orderId = location["/orders/".Length..];
                using var found = await client.GetAsync(location);
                Assert.AreEqual(HttpStatusCode.OK, found.StatusCode);

                using var invalid = await client.PostAsJsonAsync(
                    "/orders",
                    new { customerId = " ", items = Array.Empty<object>() });
                Assert.AreEqual(HttpStatusCode.BadRequest, invalid.StatusCode);
                using (var invalidBody = JsonDocument.Parse(await invalid.Content.ReadAsStringAsync()))
                {
                    validationTraceId =
                        invalidBody.RootElement.GetProperty("traceId").GetString()
                        ?? throw new AssertFailedException("Problem Details traceId is required.");
                }

                using var notFound = await client.GetAsync($"/orders/{routeCanary}");
                Assert.AreEqual(HttpStatusCode.NotFound, notFound.StatusCode);

                seams.BeforeBegin =
                    _ => throw new OrderTemporarilyUnavailableException("storage_unavailable");
                using var unavailable = await AtomicityTests.PostValid(client, "logging-unavailable");
                Assert.AreEqual(HttpStatusCode.ServiceUnavailable, unavailable.StatusCode);
                seams.BeforeBegin = previousBeforeBegin;

                seams.BeforeCommit = (_, _) => throw new InvalidOperationException(exceptionCanary);
                using var failed = await AtomicityTests.PostValid(client, "logging-failure");
                Assert.AreEqual(HttpStatusCode.InternalServerError, failed.StatusCode);
                seams.BeforeCommit = previousBeforeCommit;

                synchronizedWriter.Flush();
                var interim = buffer.ToString();
                Assert.IsFalse(interim.Contains(orderId, StringComparison.Ordinal));
            }
        }
        finally
        {
            seams.BeforeBegin = previousBeforeBegin;
            seams.BeforeCommit = previousBeforeCommit;
            synchronizedWriter.Flush();
            Console.SetOut(originalOut);
            synchronizedWriter.Dispose();
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }

        var output = buffer.ToString();
        var canaries = new[]
        {
            customerCanary,
            productCanary,
            routeCanary,
            headerCanary,
            exceptionCanary,
            databasePathCanary,
            databasePath
        };
        foreach (var canary in canaries)
        {
            Assert.IsFalse(output.Contains(canary, StringComparison.Ordinal));
        }

        var lines = output
            .Split(["\r\n", "\n"], StringSplitOptions.RemoveEmptyEntries)
            .Where(line => line.StartsWith('{'))
            .ToArray();
        Assert.IsTrue(lines.Length >= 7);
        var applicationKeys = new HashSet<string>(
            ["operation", "httpStatus", "outcome", "durationMs", "traceId", "failureCategory"],
            StringComparer.Ordinal);
        var allowedStateMetadata = new HashSet<string>(
            ["Message", "{OriginalFormat}"],
            StringComparer.Ordinal);
        var operations = new HashSet<string>(
            ["startup", "create_order", "get_order", "reject_missing_order_id"],
            StringComparer.Ordinal);
        var outcomes = new HashSet<string>(
            ["succeeded", "rejected", "not_found", "unavailable", "failed", "client_disconnected"],
            StringComparer.Ordinal);
        var failureCategories = new HashSet<string>(
            [
                "validation",
                "invalid_body",
                "unsupported_media_type",
                "writer_gate_timeout",
                "sqlite_busy",
                "storage_unavailable",
                "startup_schema",
                "uuid_collision",
                "constraint",
                "commit",
                "rollback",
                "internal"
            ],
            StringComparer.Ordinal);
        var parsed = new List<JsonDocument>();
        try
        {
            foreach (var line in lines)
            {
                Assert.IsFalse(line.Contains('\r') || line.Contains('\n'));
                var document = JsonDocument.Parse(line);
                parsed.Add(document);
                var root = document.RootElement;
                foreach (var envelopeProperty in new[]
                         {
                             "Timestamp",
                             "EventId",
                             "LogLevel",
                             "Category",
                             "Message",
                             "State"
                         })
                {
                    Assert.IsTrue(root.TryGetProperty(envelopeProperty, out _));
                }

                Assert.IsTrue(UtcTimestampRegex().IsMatch(root.GetProperty("Timestamp").GetString()!));
                Assert.AreEqual("Orders.Api", root.GetProperty("Category").GetString());
                var state = root.GetProperty("State");
                var stateKeys = state.EnumerateObject().Select(property => property.Name).ToArray();
                foreach (var key in applicationKeys)
                {
                    Assert.IsTrue(stateKeys.Contains(key, StringComparer.Ordinal));
                }

                Assert.IsTrue(
                    stateKeys.All(key => applicationKeys.Contains(key) || allowedStateMetadata.Contains(key)));
                Assert.IsTrue(operations.Contains(state.GetProperty("operation").GetString()!));
                Assert.IsTrue(outcomes.Contains(state.GetProperty("outcome").GetString()!));
                Assert.IsTrue(state.GetProperty("durationMs").GetDouble() >= 0);
                Assert.IsFalse(string.IsNullOrWhiteSpace(state.GetProperty("traceId").GetString()));
                var category = state.GetProperty("failureCategory");
                Assert.IsTrue(
                    category.ValueKind == JsonValueKind.Null
                    || failureCategories.Contains(category.GetString()!));

                if (state.GetProperty("httpStatus").ValueKind == JsonValueKind.Number)
                {
                    var status = state.GetProperty("httpStatus").GetInt32();
                    var expectedLevel = status >= 500
                        ? status == 503 ? "Warning" : "Error"
                        : "Information";
                    Assert.AreEqual(expectedLevel, root.GetProperty("LogLevel").GetString());
                }
            }

            var correlated = parsed
                .Select(document => document.RootElement.GetProperty("State"))
                .Single(
                    state =>
                        state.GetProperty("operation").GetString() == "create_order"
                        && state.GetProperty("httpStatus").ValueKind == JsonValueKind.Number
                        && state.GetProperty("httpStatus").GetInt32() == 400);
            Assert.AreEqual(validationTraceId, correlated.GetProperty("traceId").GetString());
        }
        finally
        {
            foreach (var document in parsed)
            {
                document.Dispose();
            }
        }

        Assert.IsFalse(output.Contains("\"customerId\"", StringComparison.Ordinal));
        Assert.IsFalse(output.Contains("\"productId\"", StringComparison.Ordinal));
        Assert.IsFalse(output.Contains("\"orderId\"", StringComparison.Ordinal));
        Assert.IsFalse(output.Contains("Microsoft.AspNetCore", StringComparison.Ordinal));
        Assert.IsFalse(output.Contains("Microsoft.Data.Sqlite", StringComparison.Ordinal));
        Assert.IsFalse(output.Contains("Microsoft.Hosting.Lifetime", StringComparison.Ordinal));
        Assert.IsFalse(output.Contains("SELECT ", StringComparison.OrdinalIgnoreCase));
        Assert.IsFalse(output.Contains("INSERT ", StringComparison.OrdinalIgnoreCase));
        Assert.IsFalse(output.Contains("System.", StringComparison.Ordinal));

        AssertNativeFormatterConfiguration();
    }

    [TestMethod]
    [TestCategory("Security")]
    public async Task Sc006_audits_controlled_requests_sqlite_logs_and_reports_for_prohibited_data()
    {
        const string customerId = "security-synthetic-audit-customer";
        const string productId = "security-synthetic-audit-product";
        var requestJson = JsonSerializer.Serialize(
            new
            {
                customerId,
                items = new[]
                {
                    new { productId, quantity = 1L }
                }
            });
        var report = """
            environment=synthetic-local-test
            fixtureClassification=generated-synthetic
            result=PASS
            """;
        var prohibitedMarkers = new[]
        {
            "password=",
            "authorization: bearer ",
            "api_key=",
            "secret=",
            "token=",
            "-----begin private key-----"
        };
        using var storage = TestStorage.Create();
        var originalOut = Console.Out;
        var buffer = new StringWriter(CultureInfo.InvariantCulture);
        var synchronizedWriter = TextWriter.Synchronized(buffer);
        try
        {
            Console.SetOut(synchronizedWriter);
            await using (var factory = new OrdersApiFactory(storage.DatabasePath))
            {
                using var client = factory.CreateClient();
                using var content = new StringContent(
                    requestJson,
                    System.Text.Encoding.UTF8,
                    "application/json");
                using var response = await client.PostAsync("/orders", content);
                Assert.AreEqual(HttpStatusCode.Created, response.StatusCode);
            }
        }
        finally
        {
            synchronizedWriter.Flush();
            Console.SetOut(originalOut);
            synchronizedWriter.Dispose();
        }

        var logs = buffer.ToString();
        Assert.IsFalse(logs.Contains(customerId, StringComparison.Ordinal));
        Assert.IsFalse(logs.Contains(productId, StringComparison.Ordinal));
        using (var connection = PersistenceTests.OpenRaw(storage.DatabasePath))
        {
            Assert.AreEqual(
                customerId,
                PersistenceTests.ScalarText(connection, "SELECT customer_id FROM orders LIMIT 1;"));
            Assert.AreEqual(
                productId,
                PersistenceTests.ScalarText(connection, "SELECT product_id FROM order_items LIMIT 1;"));
        }

        var databaseBytes = File.ReadAllBytes(storage.DatabasePath);
        var databaseText = System.Text.Encoding.UTF8.GetString(databaseBytes);
        foreach (var artifact in new[] { requestJson, databaseText, logs, report })
        {
            var normalized = artifact.ToLowerInvariant();
            foreach (var marker in prohibitedMarkers)
            {
                Assert.IsFalse(
                    normalized.Contains(marker, StringComparison.Ordinal),
                    $"A prohibited marker was found in a controlled SC-006 artifact: {marker}");
            }
        }

        Assert.IsTrue(requestJson.Contains("security-synthetic-", StringComparison.Ordinal));
        Assert.IsTrue(databaseText.Contains("security-synthetic-", StringComparison.Ordinal));
        Assert.IsTrue(report.Contains("fixtureClassification=generated-synthetic", StringComparison.Ordinal));

        var testsDirectory = Path.Combine(FindRepositoryRoot(), "tests");
        var unclassifiedDatasets = Directory.EnumerateFiles(
                testsDirectory,
                "*",
                SearchOption.AllDirectories)
            .Where(path =>
                !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
                && !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
                && !path.Contains($"{Path.DirectorySeparatorChar}TestResults{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
                && !path.EndsWith(".cs", StringComparison.OrdinalIgnoreCase)
                && !path.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase)
                && !path.EndsWith("packages.lock.json", StringComparison.OrdinalIgnoreCase))
            .ToArray();
        Assert.AreEqual(0, unclassifiedDatasets.Length);
    }

    private static void AssertNativeFormatterConfiguration()
    {
        var root = FindRepositoryRoot();
        using var document = JsonDocument.Parse(
            File.ReadAllText(Path.Combine(root, "src", "Orders.Api", "appsettings.json")));
        var formatterOptions = document.RootElement
            .GetProperty("Logging")
            .GetProperty("Console")
            .GetProperty("FormatterOptions");
        Assert.IsFalse(
            formatterOptions.GetProperty("JsonWriterOptions").GetProperty("Indented").GetBoolean());
        Assert.IsFalse(formatterOptions.GetProperty("IncludeScopes").GetBoolean());
        Assert.IsTrue(formatterOptions.GetProperty("UseUtcTimestamp").GetBoolean());
        Assert.AreEqual(
            "yyyy-MM-dd'T'HH:mm:ss.fff'Z'",
            formatterOptions.GetProperty("TimestampFormat").GetString());
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

    [GeneratedRegex(
        "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$",
        RegexOptions.CultureInvariant)]
    private static partial Regex UtcTimestampRegex();
}
