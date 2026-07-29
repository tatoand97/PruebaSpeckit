using FluentValidation;

namespace Orders.Application.GetOrder;

public sealed class GetOrderHandler(
    IOrderRepository repository,
    IValidator<GetOrderQuery> validator)
{
    public async Task<OrderResult> Handle(
        GetOrderQuery query,
        CancellationToken cancellationToken)
    {
        await validator.ValidateAndThrowAsync(query, cancellationToken);

        var orderId = Guid.ParseExact(query.OrderId!, "D");
        var order = await repository.GetByIdAsync(orderId, cancellationToken);

        return order is null
            ? throw new OrderNotFoundException(query.OrderId!)
            : OrderResult.From(order);
    }
}
