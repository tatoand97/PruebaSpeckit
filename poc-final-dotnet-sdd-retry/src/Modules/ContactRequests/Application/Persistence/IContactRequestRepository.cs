using ContactRequests.Domain;

namespace ContactRequests.Application.Persistence;

public interface IContactRequestRepository
{
    Task AddAsync(ContactRequest contactRequest, CancellationToken cancellationToken);

    Task<ContactRequest?> GetByIdAsync(Guid id, CancellationToken cancellationToken);
}
