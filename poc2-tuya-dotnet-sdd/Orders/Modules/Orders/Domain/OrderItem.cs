namespace Orders.Domain;

public sealed class OrderItem
{
    private OrderItem()
    {
    }

    private OrderItem(string productId, int quantity)
    {
        ProductId = productId;
        Quantity = quantity;
    }

    public string ProductId { get; private set; } = string.Empty;

    public int Quantity { get; private set; }

    public static OrderItem Create(string productId, int quantity)
    {
        if (string.IsNullOrWhiteSpace(productId))
        {
            throw new ArgumentException(
                "A product identifier must contain a non-whitespace character.",
                nameof(productId));
        }

        if (quantity <= 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(quantity),
                "Quantity must be greater than zero.");
        }

        return new OrderItem(productId, quantity);
    }
}
