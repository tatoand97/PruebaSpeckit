namespace Orders.Application;

public sealed class OrderNotFoundException(string orderId)
    : Exception($"Order '{orderId}' was not found.")
{
    public string OrderId { get; } = orderId;
}
