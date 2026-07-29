using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Orders.Application;
using Orders.Application.CreateOrder;
using Orders.Application.GetOrder;
using Wolverine;

namespace Orders.Presentation;

public static class OrdersEndpoints
{
    public static IEndpointRouteBuilder MapOrdersEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/orders").WithTags("Orders");

        group.MapPost(string.Empty, CreateOrder)
            .WithName("CreateOrder")
            .Produces<OrderResponse>(StatusCodes.Status201Created)
            .Produces<ProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")
            .Produces<ProblemDetails>(
                StatusCodes.Status500InternalServerError,
                "application/problem+json");

        group.MapGet("/{orderId}", GetOrder)
            .WithName("GetOrder")
            .Produces<OrderResponse>(StatusCodes.Status200OK)
            .Produces<ProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")
            .Produces<ProblemDetails>(StatusCodes.Status404NotFound, "application/problem+json")
            .Produces<ProblemDetails>(
                StatusCodes.Status500InternalServerError,
                "application/problem+json");

        return endpoints;
    }

    private static async Task<IResult> CreateOrder(
        CreateOrderRequest request,
        IMessageBus messageBus,
        CancellationToken cancellationToken)
    {
        var command = new CreateOrderCommand(
            request.CustomerId,
            request.Items?
                .Select(item => new CreateOrderItem(item.ProductId, item.Quantity))
                .ToArray());

        var result = await messageBus.InvokeAsync<OrderResult>(command, cancellationToken);
        var response = OrderResponse.From(result);

        return Results.Created($"/orders/{response.Id:D}", response);
    }

    private static async Task<IResult> GetOrder(
        string orderId,
        IMessageBus messageBus,
        CancellationToken cancellationToken)
    {
        var result = await messageBus.InvokeAsync<OrderResult>(
            new GetOrderQuery(orderId),
            cancellationToken);

        return Results.Ok(OrderResponse.From(result));
    }
}
