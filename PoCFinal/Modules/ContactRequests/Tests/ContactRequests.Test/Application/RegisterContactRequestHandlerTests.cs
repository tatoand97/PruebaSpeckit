using ContactRequests.Application.Abstractions;
using ContactRequests.Application.RegisterContactRequest;
using ContactRequests.Domain;
using FluentValidation;

namespace ContactRequests.Test.Application;

public sealed class RegisterContactRequestHandlerTests
{
    [Fact]
    public async Task Handle_PersistsValidRequest_AndReturnsPendingStatus()
    {
        var repository = new InMemoryRepository();
        var validator = new RegisterContactRequestValidator();
        var handler = new RegisterContactRequestHandler(repository, validator);

        var result = await handler.Handle(
            new RegisterContactRequestCommand("Alice", "alice@example.com", "Valid message 123"),
            CancellationToken.None);

        Assert.Equal("Pending", result.Status);
        Assert.Single(repository.Items);
    }

    [Fact]
    public async Task Handle_AllowsDuplicateValidRequests_AsIndependentEntries()
    {
        var repository = new InMemoryRepository();
        var validator = new RegisterContactRequestValidator();
        var handler = new RegisterContactRequestHandler(repository, validator);
        var command = new RegisterContactRequestCommand("Alice", "alice@example.com", "Valid message 123");

        var first = await handler.Handle(command, CancellationToken.None);
        var second = await handler.Handle(command, CancellationToken.None);

        Assert.NotEqual(first.Id, second.Id);
        Assert.Equal(2, repository.Items.Count);
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
