using FluentValidation;
using Orders.Domain;

namespace Orders.Application.CreateOrder;

public sealed class CreateOrderHandler(
    IOrderRepository repository,
    IValidator<CreateOrderCommand> validator,
    TimeProvider timeProvider)
{
    public async Task<OrderResult> Handle(
        CreateOrderCommand command,
        CancellationToken cancellationToken)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);

        var items = command.Items!
            .Select(item => OrderItem.Create(item.ProductId!, item.Quantity))
            .ToArray();

        var order = Order.Create(
            Guid.NewGuid(),
            command.CustomerId!,
            timeProvider.GetUtcNow(),
            items);

        await repository.AddAsync(order, cancellationToken);

        return OrderResult.From(order);
    }
}
