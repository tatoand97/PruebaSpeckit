using ContactRequests.Application.Health;

namespace ContactRequests.Tests.Application;

public sealed class GetContactRequestsHealthHandlerTests
{
    [Theory]
    [InlineData(true, "Healthy")]
    [InlineData(false, "Unhealthy")]
    public async Task Handler_returns_safe_aggregate_status(bool healthy, string expected)
    {
        var handler = new GetContactRequestsHealthHandler(new StubProbe(healthy));

        var result = await handler.Handle(
            new GetContactRequestsHealthQuery(),
            CancellationToken.None);

        Assert.Equal(expected, result.Status);
    }

    private sealed class StubProbe(bool healthy) : IContactRequestsHealthProbe
    {
        public Task<bool> IsHealthyAsync(CancellationToken cancellationToken) =>
            Task.FromResult(healthy);
    }
}
