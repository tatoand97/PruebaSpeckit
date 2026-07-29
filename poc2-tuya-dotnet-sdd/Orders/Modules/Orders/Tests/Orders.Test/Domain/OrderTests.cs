using Orders.Domain;

namespace Orders.Test.Domain;

public sealed class OrderTests
{
    private static readonly DateTimeOffset CreatedAt =
        new(2026, 7, 29, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Create_PreservesOpaqueIdentifiersAndItems()
    {
        var id = Guid.NewGuid();
        var order = Order.Create(
            id,
            " Customer-A ",
            CreatedAt,
            [OrderItem.Create(" Product-X ", 2)]);

        Assert.Equal(id, order.Id);
        Assert.Equal(" Customer-A ", order.CustomerId);
        Assert.Equal(CreatedAt, order.CreatedAt);
        var item = Assert.Single(order.Items);
        Assert.Equal(" Product-X ", item.ProductId);
        Assert.Equal(2, item.Quantity);
    }

    [Fact]
    public void Create_RejectsAnEmptyOrder()
    {
        var exception = Assert.Throws<ArgumentException>(
            () => Order.Create(Guid.NewGuid(), "customer", CreatedAt, []));

        Assert.Equal("items", exception.ParamName);
    }

    [Fact]
    public void Create_RejectsAndIdentifiesAnExactDuplicateProduct()
    {
        var exception = Assert.Throws<DuplicateProductException>(
            () => Order.Create(
                Guid.NewGuid(),
                "customer",
                CreatedAt,
                [
                    OrderItem.Create("product", 1),
                    OrderItem.Create("product", 2),
                ]));

        Assert.Equal("product", exception.ProductId);
    }

    [Fact]
    public void Create_TreatsCaseDifferentProductIdsAsDistinct()
    {
        var order = Order.Create(
            Guid.NewGuid(),
            "customer",
            CreatedAt,
            [
                OrderItem.Create("product", 1),
                OrderItem.Create("PRODUCT", 2),
            ]);

        Assert.Equal(2, order.Items.Count);
    }

    [Fact]
    public void Create_RejectsWhitespaceCustomerId()
    {
        var exception = Assert.Throws<ArgumentException>(
            () => Order.Create(
                Guid.NewGuid(),
                " \t ",
                CreatedAt,
                [OrderItem.Create("product", 1)]));

        Assert.Equal("customerId", exception.ParamName);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void OrderItem_RejectsIdentifierWithoutNonWhitespace(string productId)
    {
        var exception = Assert.Throws<ArgumentException>(
            () => OrderItem.Create(productId, 1));

        Assert.Equal("productId", exception.ParamName);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void OrderItem_RejectsNonPositiveQuantity(int quantity)
    {
        var exception = Assert.Throws<ArgumentOutOfRangeException>(
            () => OrderItem.Create("product", quantity));

        Assert.Equal("quantity", exception.ParamName);
    }
}
