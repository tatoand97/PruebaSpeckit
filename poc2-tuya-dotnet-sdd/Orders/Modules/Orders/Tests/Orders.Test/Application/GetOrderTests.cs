using FluentValidation;
using Orders.Application;
using Orders.Application.GetOrder;
using Orders.Domain;

namespace Orders.Test.Application;

public sealed class GetOrderTests
{
    [Fact]
    public async Task Handle_ReturnsAnExistingOrder()
    {
        var repository = new InMemoryOrderRepository();
        var order = CreateKnownOrder();
        repository.Seed(order);
        var handler = new GetOrderHandler(repository, new GetOrderValidator());

        var result = await handler.Handle(
            new GetOrderQuery(order.Id.ToString("D")),
            CancellationToken.None);

        Assert.Equal(order.Id, result.Id);
        Assert.Equal(order.CustomerId, result.CustomerId);
        Assert.Equal(order.CreatedAt, result.CreatedAt);
        Assert.Single(result.Items);
        Assert.Equal(1, repository.GetCalls);
    }

    [Fact]
    public async Task Handle_ReportsAnUnknownOrder()
    {
        var repository = new InMemoryOrderRepository();
        var handler = new GetOrderHandler(repository, new GetOrderValidator());
        var orderId = Guid.NewGuid().ToString("D");

        var exception = await Assert.ThrowsAsync<OrderNotFoundException>(
            () => handler.Handle(new GetOrderQuery(orderId), CancellationToken.None));

        Assert.Equal(orderId, exception.OrderId);
        Assert.Equal(1, repository.GetCalls);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    [InlineData("{11111111-1111-1111-1111-111111111111}")]
    public async Task Handle_RejectsInvalidIdentifierBeforeReading(string? orderId)
    {
        var repository = new InMemoryOrderRepository();
        var handler = new GetOrderHandler(repository, new GetOrderValidator());

        await Assert.ThrowsAsync<ValidationException>(
            () => handler.Handle(new GetOrderQuery(orderId), CancellationToken.None));

        Assert.Equal(0, repository.GetCalls);
    }

    private static Order CreateKnownOrder() =>
        Order.Create(
            Guid.NewGuid(),
            "customer",
            new DateTimeOffset(2026, 7, 29, 12, 0, 0, TimeSpan.Zero),
            [OrderItem.Create("product", 4)]);
}
