using ContactRequests.Application.Persistence;
using ContactRequests.Domain;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;

namespace ContactRequests.Infrastructure.Persistence;

public sealed class SqlContactRequestRepository(ContactRequestsDbContext dbContext)
    : IContactRequestRepository
{
    private static readonly ActivitySource ActivitySource =
        new("ContactRequests.EntityFrameworkCore");

    public async Task AddAsync(
        ContactRequest contactRequest,
        CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("ContactRequests.Add");
        await dbContext.ContactRequests.AddAsync(contactRequest, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (IsPrimaryKeyCollision(exception))
        {
            dbContext.Entry(contactRequest).State = EntityState.Detached;
            throw new ContactRequestIdentifierCollisionException(exception);
        }
    }

    public async Task<ContactRequest?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("ContactRequests.GetById");
        return await dbContext.ContactRequests
            .AsNoTracking()
            .SingleOrDefaultAsync(contactRequest => contactRequest.Id == id, cancellationToken);
    }

    private static bool IsPrimaryKeyCollision(DbUpdateException exception) =>
        exception.InnerException is SqlException { Number: 2627 } sqlException
        && sqlException.Message.Contains(
            "PK_ContactRequests",
            StringComparison.OrdinalIgnoreCase);
}
