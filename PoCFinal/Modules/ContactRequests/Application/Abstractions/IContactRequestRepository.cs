using ContactRequests.Domain;

namespace ContactRequests.Application.Abstractions;

public interface IContactRequestRepository
{
    Task AddAsync(ContactRequest contactRequest, CancellationToken cancellationToken);
}
