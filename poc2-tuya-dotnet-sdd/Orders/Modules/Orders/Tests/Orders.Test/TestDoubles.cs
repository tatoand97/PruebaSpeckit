using Orders.Application;
using Orders.Domain;

namespace Orders.Test;

internal sealed class InMemoryOrderRepository : IOrderRepository
{
    private readonly Dictionary<Guid, Order> _orders = [];

    public int AddCalls { get; private set; }

    public int GetCalls { get; private set; }

    public Task AddAsync(Order order, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        AddCalls++;
        _orders.Add(order.Id, order);
        return Task.CompletedTask;
    }

    public Task<Order?> GetByIdAsync(Guid orderId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        GetCalls++;
        _orders.TryGetValue(orderId, out var order);
        return Task.FromResult(order);
    }

    public void Seed(Order order) => _orders.Add(order.Id, order);
}

internal sealed class FixedTimeProvider(DateTimeOffset utcNow) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => utcNow;
}
