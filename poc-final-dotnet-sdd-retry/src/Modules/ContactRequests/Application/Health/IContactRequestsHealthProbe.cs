namespace ContactRequests.Application.Health;

public interface IContactRequestsHealthProbe
{
    Task<bool> IsHealthyAsync(CancellationToken cancellationToken);
}
