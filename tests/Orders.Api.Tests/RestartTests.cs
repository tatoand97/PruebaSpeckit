using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Net.Sockets;
using System.Text.Json;

namespace Orders.Api.Tests;

[TestClass]
public sealed class RestartTests
{
    [TestMethod]
    [TestCategory("Restart")]
    public async Task Confirmed_order_survives_process_termination_and_wal_recovery_with_same_storage()
    {
        using var storage = TestStorage.Create();
        string location;
        await using (var firstHost = await ApiProcessHost.StartAsync(storage.DatabasePath))
        {
            using var create = await firstHost.Client.PostAsJsonAsync(
                "/orders",
                new
                {
                    customerId = "acceptance-restart-customer",
                    items = new[]
                    {
                        new { productId = "acceptance-restart-product", quantity = 7L }
                    }
                });
            Assert.AreEqual(HttpStatusCode.Created, create.StatusCode);
            location = create.Headers.Location?.OriginalString
                ?? throw new AssertFailedException("The create response must include Location.");
            firstHost.TerminateImmediately();
        }

        await using (var restartedHost = await ApiProcessHost.StartAsync(storage.DatabasePath))
        {
            using var query = await restartedHost.Client.GetAsync(location);
            Assert.AreEqual(HttpStatusCode.OK, query.StatusCode);
            using var body = JsonDocument.Parse(await query.Content.ReadAsStringAsync());
            Assert.AreEqual(
                "acceptance-restart-customer",
                body.RootElement.GetProperty("customerId").GetString());
            Assert.AreEqual(
                "acceptance-restart-product",
                body.RootElement.GetProperty("items")[0].GetProperty("productId").GetString());
            Assert.AreEqual(7L, body.RootElement.GetProperty("items")[0].GetProperty("quantity").GetInt64());
        }

        using var lostStorage = TestStorage.Create();
        await using var recreatedFactory = new OrdersApiFactory(lostStorage.DatabasePath);
        using var recreatedClient = recreatedFactory.CreateClient();
        using var missing = await recreatedClient.GetAsync(location);
        Assert.AreEqual(HttpStatusCode.NotFound, missing.StatusCode);
    }
}

internal sealed class ApiProcessHost : IAsyncDisposable
{
    private readonly Process _process;

    private ApiProcessHost(Process process, HttpClient client)
    {
        _process = process;
        Client = client;
    }

    internal HttpClient Client { get; }

    internal static async Task<ApiProcessHost> StartAsync(string databasePath)
    {
        var port = ReserveLoopbackPort();
        var url = $"http://127.0.0.1:{port}";
        var apiAssembly = Path.Combine(AppContext.BaseDirectory, "Orders.Api.dll");
        if (!File.Exists(apiAssembly))
        {
            throw new FileNotFoundException("The Orders.Api assembly was not copied to the test output.", apiAssembly);
        }

        var startInfo = new ProcessStartInfo("dotnet")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = AppContext.BaseDirectory
        };
        startInfo.ArgumentList.Add(apiAssembly);
        startInfo.ArgumentList.Add("--urls");
        startInfo.ArgumentList.Add(url);
        startInfo.Environment["Orders__DatabasePath"] = databasePath;
        startInfo.Environment["DOTNET_ENVIRONMENT"] = "Production";

        var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("The Orders.Api process could not be started.");
        process.OutputDataReceived += static (_, _) => { };
        process.ErrorDataReceived += static (_, _) => { };
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        var client = new HttpClient
        {
            BaseAddress = new Uri(url),
            Timeout = TimeSpan.FromSeconds(5)
        };
        var deadline = Stopwatch.StartNew();
        while (deadline.Elapsed < TimeSpan.FromSeconds(10))
        {
            if (process.HasExited)
            {
                client.Dispose();
                process.Dispose();
                throw new InvalidOperationException("The Orders.Api process exited during startup.");
            }

            try
            {
                using var response = await client.GetAsync("/orders");
                if (response.StatusCode == HttpStatusCode.BadRequest)
                {
                    return new ApiProcessHost(process, client);
                }
            }
            catch (HttpRequestException)
            {
                // The loopback listener has not started yet.
            }

            await Task.Delay(50);
        }

        client.Dispose();
        process.Kill(entireProcessTree: true);
        process.Dispose();
        throw new TimeoutException("The Orders.Api process did not become ready.");
    }

    internal void TerminateImmediately()
    {
        if (!_process.HasExited)
        {
            _process.Kill(entireProcessTree: true);
            _process.WaitForExit(5_000);
        }
    }

    public ValueTask DisposeAsync()
    {
        Client.Dispose();
        TerminateImmediately();
        _process.Dispose();
        return ValueTask.CompletedTask;
    }

    private static int ReserveLoopbackPort()
    {
        var listener = new TcpListener(System.Net.IPAddress.Loopback, 0);
        listener.Start();
        try
        {
            return ((System.Net.IPEndPoint)listener.LocalEndpoint).Port;
        }
        finally
        {
            listener.Stop();
        }
    }
}
