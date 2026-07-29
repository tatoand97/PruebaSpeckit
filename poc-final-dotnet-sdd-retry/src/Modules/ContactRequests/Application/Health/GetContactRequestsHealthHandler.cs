namespace ContactRequests.Application.Health;

public sealed class GetContactRequestsHealthHandler(IContactRequestsHealthProbe healthProbe)
{
    public async Task<GetContactRequestsHealthResult> Handle(
        GetContactRequestsHealthQuery query,
        CancellationToken cancellationToken)
    {
        var isHealthy = await healthProbe.IsHealthyAsync(cancellationToken);
        return new GetContactRequestsHealthResult(isHealthy ? "Healthy" : "Unhealthy");
    }
}
