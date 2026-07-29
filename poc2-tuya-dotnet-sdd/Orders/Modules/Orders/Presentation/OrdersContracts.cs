using Orders.Application;

namespace Orders.Presentation;

public sealed record CreateOrderItemRequest(string? ProductId, int Quantity);

public sealed record CreateOrderRequest(
    string? CustomerId,
    IReadOnlyList<CreateOrderItemRequest>? Items);

public sealed record OrderItemResponse(string ProductId, int Quantity);

public sealed record OrderResponse(
    Guid Id,
    string CustomerId,
    DateTimeOffset CreatedAt,
    IReadOnlyList<OrderItemResponse> Items)
{
    public static OrderResponse From(OrderResult result) =>
        new(
            result.Id,
            result.CustomerId,
            result.CreatedAt,
            result.Items
                .Select(item => new OrderItemResponse(item.ProductId, item.Quantity))
                .ToArray());
}
