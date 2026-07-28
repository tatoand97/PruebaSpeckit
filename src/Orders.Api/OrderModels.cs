namespace Orders.Api;

internal static class OrderStatuses
{
    internal const string Pending = "Pending";
}

internal sealed record OrderItem
{
    internal OrderItem(string productId, long quantity)
    {
        if (string.IsNullOrWhiteSpace(productId))
        {
            throw new ArgumentException("A product identifier is required.", nameof(productId));
        }

        if (quantity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(quantity));
        }

        ProductId = productId;
        Quantity = quantity;
    }

    internal string ProductId { get; }

    internal long Quantity { get; }
}

internal sealed record Order
{
    internal Order(
        string orderId,
        string customerId,
        IReadOnlyList<OrderItem> items,
        string status = OrderStatuses.Pending)
    {
        if (!Guid.TryParseExact(orderId, "D", out var parsed)
            || parsed.Version != 4
            || !string.Equals(parsed.ToString("D"), orderId, StringComparison.Ordinal))
        {
            throw new ArgumentException("The order identifier must be a canonical UUID v4.", nameof(orderId));
        }

        if (string.IsNullOrWhiteSpace(customerId))
        {
            throw new ArgumentException("A customer identifier is required.", nameof(customerId));
        }

        ArgumentNullException.ThrowIfNull(items);
        if (items.Count == 0)
        {
            throw new ArgumentException("At least one item is required.", nameof(items));
        }

        if (!string.Equals(status, OrderStatuses.Pending, StringComparison.Ordinal))
        {
            throw new ArgumentException("Pending is the only supported state.", nameof(status));
        }

        var identifiers = new HashSet<string>(StringComparer.Ordinal);
        foreach (var item in items)
        {
            ArgumentNullException.ThrowIfNull(item);
            if (!identifiers.Add(item.ProductId))
            {
                throw new ArgumentException("Product identifiers must be ordinally unique.", nameof(items));
            }
        }

        OrderId = orderId;
        CustomerId = customerId;
        Items = items.ToArray();
        Status = status;
    }

    internal string OrderId { get; }

    internal string CustomerId { get; }

    internal IReadOnlyList<OrderItem> Items { get; }

    internal string Status { get; }
}

