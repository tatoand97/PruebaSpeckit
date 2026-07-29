namespace Orders.Domain;

public sealed class Order
{
    private readonly List<OrderItem> _items = [];

    private Order()
    {
    }

    private Order(
        Guid id,
        string customerId,
        DateTimeOffset createdAt,
        IEnumerable<OrderItem> items)
    {
        Id = id;
        CustomerId = customerId;
        CreatedAt = createdAt;
        _items.AddRange(items);
    }

    public Guid Id { get; private set; }

    public string CustomerId { get; private set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; private set; }

    public IReadOnlyList<OrderItem> Items => _items;

    public static Order Create(
        Guid id,
        string customerId,
        DateTimeOffset createdAt,
        IReadOnlyCollection<OrderItem> items)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("Order identifier cannot be empty.", nameof(id));
        }

        if (string.IsNullOrWhiteSpace(customerId))
        {
            throw new ArgumentException(
                "A customer identifier must contain a non-whitespace character.",
                nameof(customerId));
        }

        if (items.Count == 0)
        {
            throw new ArgumentException("An order must contain at least one item.", nameof(items));
        }

        var duplicateProduct = items
            .GroupBy(item => item.ProductId, StringComparer.Ordinal)
            .FirstOrDefault(group => group.Count() > 1);

        if (duplicateProduct is not null)
        {
            throw new DuplicateProductException(duplicateProduct.Key);
        }

        return new Order(id, customerId, createdAt, items);
    }
}
