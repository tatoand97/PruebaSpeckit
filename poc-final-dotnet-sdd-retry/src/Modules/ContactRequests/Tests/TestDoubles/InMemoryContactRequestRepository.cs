using ContactRequests.Application.Persistence;
using ContactRequests.Domain;

namespace ContactRequests.Tests.TestDoubles;

public sealed class InMemoryContactRequestRepository : IContactRequestRepository
{
    private readonly List<ContactRequest> items = [];

    public int CollisionsRemaining { get; set; }

    public int AddCalls { get; private set; }

    public Exception? GetException { get; set; }

    public IReadOnlyList<ContactRequest> Items => items;

    public List<Guid> AttemptedIds { get; } = [];

    public Task AddAsync(ContactRequest contactRequest, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        AddCalls++;
        AttemptedIds.Add(contactRequest.Id);

        if (CollisionsRemaining > 0)
        {
            CollisionsRemaining--;
            throw new ContactRequestIdentifierCollisionException();
        }

        items.Add(contactRequest);
        return Task.CompletedTask;
    }

    public Task<ContactRequest?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (GetException is not null)
        {
            throw GetException;
        }

        return Task.FromResult(items.SingleOrDefault(item => item.Id == id));
    }

    public void Seed(ContactRequest contactRequest) => items.Add(contactRequest);
}
