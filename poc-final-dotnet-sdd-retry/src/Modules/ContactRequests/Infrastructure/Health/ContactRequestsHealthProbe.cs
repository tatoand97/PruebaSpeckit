using ContactRequests.Application.Health;
using ContactRequests.Infrastructure.Persistence;

namespace ContactRequests.Infrastructure.Health;

public sealed class ContactRequestsHealthProbe(ContactRequestsDbContext dbContext)
    : IContactRequestsHealthProbe
{
    public async Task<bool> IsHealthyAsync(CancellationToken cancellationToken)
    {
        try
        {
            return await dbContext.Database.CanConnectAsync(cancellationToken);
        }
        catch
        {
            return false;
        }
    }
}
