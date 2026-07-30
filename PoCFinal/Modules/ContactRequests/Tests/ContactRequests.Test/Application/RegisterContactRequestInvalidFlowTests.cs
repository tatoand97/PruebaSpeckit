using ContactRequests.Application.Abstractions;
using ContactRequests.Application.Errors;
using ContactRequests.Application.RegisterContactRequest;
using ContactRequests.Domain;
using FluentValidation;

namespace ContactRequests.Test.Application;

public sealed class RegisterContactRequestInvalidFlowTests
{
    [Fact]
    public async Task Handle_DoesNotPersist_WhenValidationFails()
    {
        var repository = new InMemoryRepository();
        var validator = new RegisterContactRequestValidator();
        var handler = new RegisterContactRequestHandler(repository, validator);

        await Assert.ThrowsAsync<ContactRequestValidationException>(() =>
            handler.Handle(
                new RegisterContactRequestCommand("", "bad-email", "short"),
                CancellationToken.None));

        Assert.Empty(repository.Items);
    }

    private sealed class InMemoryRepository : IContactRequestRepository
    {
        public List<ContactRequest> Items { get; } = [];

        public Task AddAsync(ContactRequest contactRequest, CancellationToken cancellationToken)
        {
            Items.Add(contactRequest);
            return Task.CompletedTask;
        }
    }
}
