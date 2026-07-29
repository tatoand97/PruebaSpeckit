using ContactRequests.Application.GetById;
using ContactRequests.Domain;
using ContactRequests.Tests.TestDoubles;
using FluentValidation;

namespace ContactRequests.Tests.Application;

public sealed class GetContactRequestHandlerTests
{
    private static readonly DateTimeOffset CreatedAtUtc =
        new(2026, 7, 29, 15, 30, 0, TimeSpan.Zero);

    [Fact]
    public async Task Handle_returns_all_six_fields_for_exact_identifier()
    {
        var repository = new InMemoryContactRequestRepository();
        var contactRequest = ContactRequest.Create(
            Guid.CreateVersion7(),
            "Ada",
            "ada@example.test",
            "Subject",
            "Message",
            CreatedAtUtc);
        repository.Seed(contactRequest);
        var handler = CreateHandler(repository);

        var result = await InvokeAsync(
            handler,
            new GetContactRequestQuery(contactRequest.Id.ToString("D")),
            CancellationToken.None);

        Assert.Equal(contactRequest.Id, result.Id);
        Assert.Equal(contactRequest.Name, result.Name);
        Assert.Equal(contactRequest.Email, result.Email);
        Assert.Equal(contactRequest.Subject, result.Subject);
        Assert.Equal(contactRequest.Message, result.Message);
        Assert.Equal(contactRequest.CreatedAtUtc, result.CreatedAtUtc);
    }

    [Fact]
    public async Task Malformed_identifier_produces_uniform_validation_failure()
    {
        var handler = CreateHandler(new InMemoryContactRequestRepository());

        var exception = await Assert.ThrowsAsync<ValidationException>(() =>
            InvokeAsync(
                handler,
                new GetContactRequestQuery("not-an-existing-id"),
                CancellationToken.None));

        Assert.All(
            exception.Errors,
            error => Assert.Equal(
                GetContactRequestQueryValidator.ExactIdentifierNotFoundErrorCode,
                error.ErrorCode));
    }

    [Fact]
    public async Task Unknown_identifier_produces_known_not_found_failure()
    {
        var handler = CreateHandler(new InMemoryContactRequestRepository());

        await Assert.ThrowsAsync<ContactRequestNotFoundException>(() =>
            InvokeAsync(
                handler,
                new GetContactRequestQuery(Guid.CreateVersion7().ToString("D")),
                CancellationToken.None));
    }

    [Fact]
    public async Task Unexpected_repository_failure_is_propagated()
    {
        var expected = new InvalidOperationException("synthetic failure");
        var repository = new InMemoryContactRequestRepository { GetException = expected };
        var handler = CreateHandler(repository);

        var actual = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            InvokeAsync(
                handler,
                new GetContactRequestQuery(Guid.CreateVersion7().ToString("D")),
                CancellationToken.None));

        Assert.Same(expected, actual);
    }

    private static GetContactRequestHandler CreateHandler(
        InMemoryContactRequestRepository repository) =>
        new(repository);

    private static async Task<GetContactRequestResult> InvokeAsync(
        GetContactRequestHandler handler,
        GetContactRequestQuery query,
        CancellationToken cancellationToken)
    {
        await GetContactRequestHandler.ValidateAsync(
            query,
            new GetContactRequestQueryValidator(),
            cancellationToken);
        return await handler.Handle(query, cancellationToken);
    }
}
