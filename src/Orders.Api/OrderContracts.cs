using Microsoft.AspNetCore.Mvc;

namespace Orders.Api;

internal sealed record CreateOrderRequest(
    string? CustomerId,
    IReadOnlyList<CreateOrderItemRequest?>? Items);

internal sealed record CreateOrderItemRequest(
    string? ProductId,
    long? Quantity);

internal sealed record CreateOrderResponse(
    string OrderId,
    string Status);

internal sealed record OrderResponse(
    string OrderId,
    string CustomerId,
    IReadOnlyList<OrderItemResponse> Items,
    string Status)
{
    internal static OrderResponse FromOrder(Order order) =>
        new(
            order.OrderId,
            order.CustomerId,
            order.Items.Select(item => new OrderItemResponse(item.ProductId, item.Quantity)).ToArray(),
            order.Status);
}

internal sealed record OrderItemResponse(
    string ProductId,
    long Quantity);

internal static class OrderProblems
{
    internal const string OrdersInstance = "/orders";
    internal const string OrderByIdInstance = "/orders/{orderId}";

    internal static IResult InvalidBody(HttpContext context) =>
        ValidationProblem(
            context,
            "urn:orders:problem:invalid-body",
            "El cuerpo JSON no es válido.",
            "El body debe ser un objeto JSON válido con los tipos declarados.",
            OrdersInstance,
            new Dictionary<string, string[]>(StringComparer.Ordinal)
            {
                ["body"] = ["No fue posible interpretar el cuerpo."]
            });

    internal static IResult Validation(
        HttpContext context,
        string instance,
        IReadOnlyDictionary<string, string[]> errors) =>
        ValidationProblem(
            context,
            "urn:orders:problem:validation",
            "La solicitud no es válida.",
            "Se detectaron errores de validación semántica.",
            instance,
            errors);

    internal static IResult MissingOrderId(HttpContext context) =>
        ValidationProblem(
            context,
            "urn:orders:problem:missing-order-id",
            "Falta el identificador de orden.",
            "Use la ruta Location devuelta al crear la orden.",
            OrdersInstance,
            new Dictionary<string, string[]>(StringComparer.Ordinal)
            {
                ["orderId"] = ["Debe proporcionar el identificador exacto de la orden."]
            });

    internal static IResult NotFound(HttpContext context) =>
        Problem(
            context,
            StatusCodes.Status404NotFound,
            "urn:orders:problem:not-found",
            "Orden no encontrada.",
            "No existe una orden asociada al identificador proporcionado.",
            OrderByIdInstance);

    internal static IResult UnsupportedMediaType(HttpContext context) =>
        Problem(
            context,
            StatusCodes.Status415UnsupportedMediaType,
            "urn:orders:problem:unsupported-media-type",
            "Content-Type no soportado.",
            "Use application/json.",
            OrdersInstance);

    internal static IResult Internal(HttpContext context, string instance) =>
        Problem(
            context,
            StatusCodes.Status500InternalServerError,
            "urn:orders:problem:internal",
            "Error interno.",
            "La operación no pudo completarse.",
            instance);

    internal static IResult TemporarilyUnavailable(HttpContext context, string instance) =>
        Problem(
            context,
            StatusCodes.Status503ServiceUnavailable,
            "urn:orders:problem:temporarily-unavailable",
            "Servicio temporalmente no disponible.",
            "La operación no pudo completarse temporalmente.",
            instance);

    private static IResult ValidationProblem(
        HttpContext context,
        string type,
        string title,
        string detail,
        string instance,
        IReadOnlyDictionary<string, string[]> errors)
    {
        var problem = new HttpValidationProblemDetails(
            errors.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal))
        {
            Type = type,
            Title = title,
            Status = StatusCodes.Status400BadRequest,
            Detail = detail,
            Instance = instance
        };
        problem.Extensions["traceId"] = context.TraceIdentifier;

        return Results.Json(
            problem,
            statusCode: StatusCodes.Status400BadRequest,
            contentType: "application/problem+json");
    }

    private static IResult Problem(
        HttpContext context,
        int status,
        string type,
        string title,
        string detail,
        string instance)
    {
        var problem = new ProblemDetails
        {
            Type = type,
            Title = title,
            Status = status,
            Detail = detail,
            Instance = instance
        };
        problem.Extensions["traceId"] = context.TraceIdentifier;

        return Results.Json(problem, statusCode: status, contentType: "application/problem+json");
    }
}

