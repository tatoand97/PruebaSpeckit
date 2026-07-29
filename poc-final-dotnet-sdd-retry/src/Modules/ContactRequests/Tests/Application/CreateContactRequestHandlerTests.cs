using ContactRequests.Application.Create;
using ContactRequests.Tests.TestDoubles;

namespace ContactRequests.Tests.Application;

public sealed class CreateContactRequestHandlerTests
{
    private static readonly DateTimeOffset CreatedAtUtc =
        new(2026, 7, 29, 15, 30, 0, TimeSpan.Zero);

    private static readonly CreateContactRequestCommand ValidCommand =
        new("Ada Lovelace", "ada@example.test", "Subject", "Synthetic message");

    [Fact]
    public async Task Handle_creates_exactly_one_request()
    {
        var repository = new InMemoryContactRequestRepository();
        var handler = CreateHandler(repository);

        var result = await handler.Handle(ValidCommand, CancellationToken.None);

        Assert.Single(repository.Items);
        Assert.Equal(1, repository.AddCalls);
        Assert.Equal(result.Id, repository.Items[0].Id);
        Assert.Equal(CreatedAtUtc, result.CreatedAtUtc);
    }

    [Fact]
    public async Task Identical_commands_create_distinct_identifiers()
    {
        var repository = new InMemoryContactRequestRepository();
        var handler = CreateHandler(repository);

        var first = await handler.Handle(ValidCommand, CancellationToken.None);
        var second = await handler.Handle(ValidCommand, CancellationToken.None);

        Assert.NotEqual(first.Id, second.Id);
        Assert.Equal(2, repository.Items.Count);
    }

    [Fact]
    public async Task Handle_retries_collisions_three_total_times_with_one_timestamp()
    {
        var repository = new InMemoryContactRequestRepository { CollisionsRemaining = 2 };
        var handler = CreateHandler(repository);

        var result = await handler.Handle(ValidCommand, CancellationToken.None);

        Assert.Equal(3, repository.AddCalls);
        Assert.Equal(3, repository.AttemptedIds.Distinct().Count());
        Assert.Single(repository.Items);
        Assert.Equal(CreatedAtUtc, result.CreatedAtUtc);
        Assert.Equal(CreatedAtUtc, repository.Items[0].CreatedAtUtc);
    }

    [Fact]
    public async Task Handle_exhaustion_leaves_no_created_request()
    {
        var repository = new InMemoryContactRequestRepository { CollisionsRemaining = 3 };
        var handler = CreateHandler(repository);

        await Assert.ThrowsAsync<ContactRequestIdentifierAllocationException>(() =>
            handler.Handle(ValidCommand, CancellationToken.None));

        Assert.Equal(3, repository.AddCalls);
        Assert.Empty(repository.Items);
    }

    private static CreateContactRequestHandler CreateHandler(
        InMemoryContactRequestRepository repository) =>
        new(
            repository,
            new StubTimeProvider(CreatedAtUtc));
}
