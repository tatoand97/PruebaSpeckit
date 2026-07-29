using ContactRequests.Application.Create;
using ContactRequests.Tests.TestDoubles;
using FluentValidation;

namespace ContactRequests.Tests.Application;

public sealed class CreateContactRequestInvalidInputHandlerTests
{
    [Fact]
    public async Task Application_boundary_does_not_invoke_repository_for_invalid_input()
    {
        var repository = new InMemoryContactRequestRepository();
        var handler = new CreateContactRequestHandler(
            repository,
            TimeProvider.System);

        await Assert.ThrowsAsync<ValidationException>(() =>
            CreateContactRequestHandler.ValidateAsync(
                new CreateContactRequestCommand(" ", "invalid", null, ""),
                new CreateContactRequestValidator(),
                CancellationToken.None));

        Assert.Equal(0, repository.AddCalls);
        Assert.Empty(repository.Items);
    }
}
