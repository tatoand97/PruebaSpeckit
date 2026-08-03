using ContactRequests.Application.Abstractions;
using ContactRequests.Domain;
using ContactRequests.Infrastructure.Persistence;

namespace ContactRequests.Infrastructure.Repositories;

public sealed class EfContactRequestRepository(ContactRequestsDbContext dbContext) : IContactRequestRepository
{
    public async Task AddAsync(ContactRequest contactRequest, CancellationToken cancellationToken)
    {
        var entity = new ContactRequestEntity
        {
            Id = contactRequest.Id,
            Name = contactRequest.Name,
            Email = contactRequest.Email,
            Message = contactRequest.Message,
            CreatedAt = contactRequest.CreatedAt,
            Status = contactRequest.Status.ToString()
        };

        dbContext.ContactRequests.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
