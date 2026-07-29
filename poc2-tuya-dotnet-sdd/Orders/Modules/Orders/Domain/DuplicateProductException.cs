namespace Orders.Domain;

public sealed class DuplicateProductException(string productId)
    : Exception($"Product '{productId}' appears more than once in the order.")
{
    public string ProductId { get; } = productId;
}
