using FluentValidation;
using Orders.Application.CreateOrder;
using Orders.Domain;

namespace Orders.Test.Application;

public sealed class CreateOrderTests
{
    private static readonly DateTimeOffset CreatedAt =
        new(2026, 7, 29, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Handle_CreatesAndWritesOneCompleteOrder()
    {
        var repository = new InMemoryOrderRepository();
        var handler = CreateHandler(repository);
        var command = ValidCommand();

        var result = await handler.Handle(command, CancellationToken.None);

        Assert.NotEqual(Guid.Empty, result.Id);
        Assert.Equal("customer-1", result.CustomerId);
        Assert.Equal(CreatedAt, result.CreatedAt);
        Assert.Equal(2, result.Items.Count);
        Assert.Equal(1, repository.AddCalls);

        var stored = await repository.GetByIdAsync(result.Id, CancellationToken.None);
        Assert.NotNull(stored);
        Assert.Equal(result.Id, stored.Id);
    }

    [Fact]
    public async Task Handle_CreatesDifferentIdsForIdenticalRequests()
    {
        var repository = new InMemoryOrderRepository();
        var handler = CreateHandler(repository);
        var command = ValidCommand();

        var first = await handler.Handle(command, CancellationToken.None);
        var second = await handler.Handle(command, CancellationToken.None);

        Assert.NotEqual(first.Id, second.Id);
        Assert.Equal(2, repository.AddCalls);
    }

    [Fact]
    public async Task Handle_RejectsInvalidInputWithoutWriting()
    {
        var repository = new InMemoryOrderRepository();
        var handler = CreateHandler(repository);
        var command = new CreateOrderCommand(
            " ",
            [new CreateOrderItem(" ", 0)]);

        var exception = await Assert.ThrowsAsync<ValidationException>(
            () => handler.Handle(command, CancellationToken.None));

        Assert.Contains(exception.Errors, error => error.PropertyName == "CustomerId");
        Assert.Contains(exception.Errors, error => error.PropertyName == "Items[0].ProductId");
        Assert.Contains(exception.Errors, error => error.PropertyName == "Items[0].Quantity");
        Assert.Equal(0, repository.AddCalls);
    }

    [Fact]
    public async Task Handle_RejectsMissingItemsWithoutWriting()
    {
        var repository = new InMemoryOrderRepository();
        var handler = CreateHandler(repository);
        var command = new CreateOrderCommand("customer", null);

        var exception = await Assert.ThrowsAsync<ValidationException>(
            () => handler.Handle(command, CancellationToken.None));

        Assert.Contains(exception.Errors, error => error.PropertyName == "Items");
        Assert.Equal(0, repository.AddCalls);
    }

    [Fact]
    public async Task Handle_RejectsDuplicateProductWithoutWriting()
    {
        var repository = new InMemoryOrderRepository();
        var handler = CreateHandler(repository);
        var command = new CreateOrderCommand(
            "customer",
            [
                new CreateOrderItem("duplicate", 1),
                new CreateOrderItem("duplicate", 2),
            ]);

        var exception = await Assert.ThrowsAsync<DuplicateProductException>(
            () => handler.Handle(command, CancellationToken.None));

        Assert.Equal("duplicate", exception.ProductId);
        Assert.Equal(0, repository.AddCalls);
    }

    private static CreateOrderHandler CreateHandler(InMemoryOrderRepository repository) =>
        new(repository, new CreateOrderValidator(), new FixedTimeProvider(CreatedAt));

    private static CreateOrderCommand ValidCommand() =>
        new(
            "customer-1",
            [
                new CreateOrderItem("product-1", 2),
                new CreateOrderItem("PRODUCT-1", 3),
            ]);
}
