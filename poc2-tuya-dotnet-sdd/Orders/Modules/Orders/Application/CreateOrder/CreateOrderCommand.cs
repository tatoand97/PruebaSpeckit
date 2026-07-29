namespace Orders.Application.CreateOrder;

public sealed record CreateOrderItem(string? ProductId, int Quantity);

public sealed record CreateOrderCommand(
    string? CustomerId,
    IReadOnlyList<CreateOrderItem>? Items);
