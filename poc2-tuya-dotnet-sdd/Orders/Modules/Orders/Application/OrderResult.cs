using Orders.Domain;

namespace Orders.Application;

public sealed record OrderItemResult(string ProductId, int Quantity);

public sealed record OrderResult(
    Guid Id,
    string CustomerId,
    DateTimeOffset CreatedAt,
    IReadOnlyList<OrderItemResult> Items)
{
    public static OrderResult From(Order order) =>
        new(
            order.Id,
            order.CustomerId,
            order.CreatedAt,
            order.Items
                .Select(item => new OrderItemResult(item.ProductId, item.Quantity))
                .ToArray());
}
