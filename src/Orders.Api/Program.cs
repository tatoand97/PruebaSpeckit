using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Routing;
using Orders.Api;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 1_048_576;
});

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DictionaryKeyPolicy = null;
    options.SerializerOptions.PropertyNameCaseInsensitive = false;
    options.SerializerOptions.NumberHandling = JsonNumberHandling.Strict;
    options.SerializerOptions.AllowDuplicateProperties = false;
    options.SerializerOptions.UnmappedMemberHandling = JsonUnmappedMemberHandling.Skip;
    options.SerializerOptions.ReadCommentHandling = JsonCommentHandling.Disallow;
    options.SerializerOptions.AllowTrailingCommas = false;
});

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<SafeExceptionHandler>();
builder.Services.AddSingleton(new SemaphoreSlim(1, 1));
builder.Services.AddSingleton<OrderTestSeams>();
builder.Services.AddSingleton(sp =>
{
    var configuration = sp.GetRequiredService<IConfiguration>();
    var databasePath = configuration["Orders:DatabasePath"];
    if (string.IsNullOrWhiteSpace(databasePath))
    {
        throw new InvalidOperationException("Orders:DatabasePath is required.");
    }

    return new SqliteOrderStore(
        databasePath,
        sp.GetRequiredService<SemaphoreSlim>(),
        sp.GetRequiredService<OrderTestSeams>());
});

var app = builder.Build();
app.UseExceptionHandler();

var startupTimer = Stopwatch.StartNew();
var applicationLogger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Orders.Api");
try
{
    app.Services.GetRequiredService<SqliteOrderStore>().Initialize();
    startupTimer.Stop();
    OrderLog.Write(
        applicationLogger,
        LogLevel.Information,
        "startup",
        null,
        "succeeded",
        startupTimer.Elapsed.TotalMilliseconds,
        "startup",
        null);
}
catch
{
    startupTimer.Stop();
    OrderLog.Write(
        applicationLogger,
        LogLevel.Error,
        "startup",
        null,
        "failed",
        startupTimer.Elapsed.TotalMilliseconds,
        "startup",
        "startup_schema");
    throw;
}

app.MapPost(
    "/orders",
    async (
        HttpContext context,
        SqliteOrderStore store,
        OrderTestSeams seams,
        ILoggerFactory loggerFactory,
        CancellationToken cancellationToken) =>
    {
        var timer = Stopwatch.StartNew();
        var logger = loggerFactory.CreateLogger("Orders.Api");
        if (!HasSupportedJsonContentType(context.Request))
        {
            timer.Stop();
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "create_order",
                StatusCodes.Status415UnsupportedMediaType,
                "rejected",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                "unsupported_media_type");
            return OrderProblems.UnsupportedMediaType(context);
        }

        CreateOrderRequest? request;
        try
        {
            request = await context.Request.ReadFromJsonAsync<CreateOrderRequest>(
                cancellationToken);
        }
        catch (JsonException)
        {
            timer.Stop();
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "create_order",
                StatusCodes.Status400BadRequest,
                "rejected",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                "invalid_body");
            return OrderProblems.InvalidBody(context);
        }
        catch (NotSupportedException)
        {
            timer.Stop();
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "create_order",
                StatusCodes.Status400BadRequest,
                "rejected",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                "invalid_body");
            return OrderProblems.InvalidBody(context);
        }

        if (request is null)
        {
            timer.Stop();
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "create_order",
                StatusCodes.Status400BadRequest,
                "rejected",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                "invalid_body");
            return OrderProblems.InvalidBody(context);
        }

        var validation = OrderValidator.Validate(request);
        if (!validation.IsValid)
        {
            timer.Stop();
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "create_order",
                StatusCodes.Status400BadRequest,
                "rejected",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                "validation");
            return OrderProblems.Validation(
                context,
                OrderProblems.OrdersInstance,
                validation.Errors);
        }

        Order order;
        try
        {
            order = await store.CreateAsync(validation.Value!, cancellationToken);
            seams.PostCommitPreResponse(order.OrderId);
        }
        catch (OrderTemporarilyUnavailableException exception)
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "create_order",
                StatusCodes.Status503ServiceUnavailable,
                "unavailable",
                exception.Category,
                OrderProblems.TemporarilyUnavailable(context, OrderProblems.OrdersInstance));
        }
        catch (OrderUuidCollisionException)
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "create_order",
                StatusCodes.Status500InternalServerError,
                "failed",
                "uuid_collision",
                OrderProblems.Internal(context, OrderProblems.OrdersInstance));
        }
        catch (OrderCommitUncertainException)
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "create_order",
                StatusCodes.Status500InternalServerError,
                "failed",
                "commit",
                OrderProblems.Internal(context, OrderProblems.OrdersInstance));
        }
        catch (OrderConfirmedPostCommitException)
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "create_order",
                StatusCodes.Status500InternalServerError,
                "failed",
                "commit",
                OrderProblems.Internal(context, OrderProblems.OrdersInstance));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "create_order",
                StatusCodes.Status500InternalServerError,
                "failed",
                "internal",
                OrderProblems.Internal(context, OrderProblems.OrdersInstance));
        }

        timer.Stop();
        OrderLog.Write(
            logger,
            LogLevel.Information,
            "create_order",
            StatusCodes.Status201Created,
            "succeeded",
            timer.Elapsed.TotalMilliseconds,
            context.TraceIdentifier,
            null);
        return Results.Created(
            $"/orders/{order.OrderId}",
            new CreateOrderResponse(order.OrderId, order.Status));
    });

app.MapGet(
    "/orders/{orderId}",
    (
        string orderId,
        HttpContext context,
        SqliteOrderStore store,
        ILoggerFactory loggerFactory) =>
    {
        var timer = Stopwatch.StartNew();
        var logger = loggerFactory.CreateLogger("Orders.Api");
        if (string.IsNullOrWhiteSpace(orderId))
        {
            timer.Stop();
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "get_order",
                StatusCodes.Status400BadRequest,
                "rejected",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                "validation");
            return OrderProblems.Validation(
                context,
                OrderProblems.OrderByIdInstance,
                new Dictionary<string, string[]>(StringComparer.Ordinal)
                {
                    ["orderId"] = ["Debe contener al menos un carácter distinto de espacio."]
                });
        }

        Order? order;
        try
        {
            order = store.Get(orderId);
        }
        catch (OrderTemporarilyUnavailableException exception)
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "get_order",
                StatusCodes.Status503ServiceUnavailable,
                "unavailable",
                exception.Category,
                OrderProblems.TemporarilyUnavailable(context, OrderProblems.OrderByIdInstance));
        }
        catch
        {
            return CompleteProblem(
                context,
                logger,
                timer,
                "get_order",
                StatusCodes.Status500InternalServerError,
                "failed",
                "internal",
                OrderProblems.Internal(context, OrderProblems.OrderByIdInstance));
        }

        timer.Stop();
        if (order is null)
        {
            OrderLog.Write(
                logger,
                LogLevel.Information,
                "get_order",
                StatusCodes.Status404NotFound,
                "not_found",
                timer.Elapsed.TotalMilliseconds,
                context.TraceIdentifier,
                null);
            return OrderProblems.NotFound(context);
        }

        OrderLog.Write(
            logger,
            LogLevel.Information,
            "get_order",
            StatusCodes.Status200OK,
            "succeeded",
            timer.Elapsed.TotalMilliseconds,
            context.TraceIdentifier,
            null);
        return Results.Json(OrderResponse.FromOrder(order));
    });

app.MapGet(
    "/orders",
    (HttpContext context, ILoggerFactory loggerFactory) =>
    {
        var logger = loggerFactory.CreateLogger("Orders.Api");
        OrderLog.Write(
            logger,
            LogLevel.Information,
            "reject_missing_order_id",
            StatusCodes.Status400BadRequest,
            "rejected",
            0,
            context.TraceIdentifier,
            "validation");
        return OrderProblems.MissingOrderId(context);
    });

app.Run();

static bool HasSupportedJsonContentType(HttpRequest request)
{
    if (string.IsNullOrWhiteSpace(request.ContentType)
        || !Microsoft.Net.Http.Headers.MediaTypeHeaderValue.TryParse(
            request.ContentType,
            out var parsed))
    {
        return false;
    }

    return string.Equals(parsed.MediaType.Value, "application/json", StringComparison.OrdinalIgnoreCase);
}

static IResult CompleteProblem(
    HttpContext context,
    ILogger logger,
    Stopwatch timer,
    string operation,
    int status,
    string outcome,
    string failureCategory,
    IResult problem)
{
    timer.Stop();
    OrderLog.Write(
        logger,
        status == StatusCodes.Status503ServiceUnavailable ? LogLevel.Warning : LogLevel.Error,
        operation,
        status,
        outcome,
        timer.Elapsed.TotalMilliseconds,
        context.TraceIdentifier,
        failureCategory);
    return problem;
}

internal sealed class SafeExceptionHandler(
    ILoggerFactory loggerFactory) : IExceptionHandler
{
    private readonly ILogger _logger = loggerFactory.CreateLogger("Orders.Api");

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        _ = exception;
        if (httpContext.Response.HasStarted)
        {
            return false;
        }

        var (operation, instance) = ResolveRoute(httpContext);
        OrderLog.Write(
            _logger,
            LogLevel.Error,
            operation,
            StatusCodes.Status500InternalServerError,
            "failed",
            0,
            httpContext.TraceIdentifier,
            "internal");

        await OrderProblems.Internal(httpContext, instance).ExecuteAsync(httpContext);
        return true;
    }

    private static (string Operation, string Instance) ResolveRoute(HttpContext context)
    {
        var routeTemplate = (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText;
        if (string.Equals(routeTemplate, OrderProblems.OrderByIdInstance, StringComparison.Ordinal))
        {
            return ("get_order", OrderProblems.OrderByIdInstance);
        }

        if (HttpMethods.IsGet(context.Request.Method))
        {
            return ("reject_missing_order_id", OrderProblems.OrdersInstance);
        }

        return ("create_order", OrderProblems.OrdersInstance);
    }
}

internal static class OrderLog
{
    internal static void Write(
        ILogger logger,
        LogLevel level,
        string operation,
        int? httpStatus,
        string outcome,
        double durationMs,
        string traceId,
        string? failureCategory)
    {
        var state = new Dictionary<string, object?>(StringComparer.Ordinal)
        {
            ["operation"] = operation,
            ["httpStatus"] = httpStatus,
            ["outcome"] = outcome,
            ["durationMs"] = Math.Max(0, durationMs),
            ["traceId"] = traceId,
            ["failureCategory"] = failureCategory
        };

        logger.Log(
            level,
            new EventId(EventIdFor(operation), operation),
            state,
            null,
            static (values, _) =>
                $"{values["operation"]} {values["outcome"]} {values["httpStatus"]}");
    }

    private static int EventIdFor(string operation) =>
        operation switch
        {
            "startup" => 1000,
            "create_order" => 1001,
            "get_order" => 1002,
            "reject_missing_order_id" => 1003,
            _ => 1099
        };
}

public partial class Program;
