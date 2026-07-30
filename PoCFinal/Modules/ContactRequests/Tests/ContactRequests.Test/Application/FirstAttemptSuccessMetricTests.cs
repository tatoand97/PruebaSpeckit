using ContactRequests.Application.Abstractions;
using ContactRequests.Application.RegisterContactRequest;
using ContactRequests.Domain;

namespace ContactRequests.Test.Application;

public sealed class FirstAttemptSuccessMetricTests
{
    [Fact]
    public async Task SampleOfTwentyValidAttempts_HasAtLeastNineteenFirstTrySuccesses()
    {
        var repository = new InMemoryRepository();
        var validator = new RegisterContactRequestValidator();
        var handler = new RegisterContactRequestHandler(repository, validator);

        var successfulAttempts = 0;

        for (var i = 0; i < 20; i++)
        {
            var command = new RegisterContactRequestCommand($"User {i}", $"user{i}@example.com", "Valid message 12345");
            var result = await handler.Handle(command, CancellationToken.None);
            if (result.Status == "Pending")
            {
                successfulAttempts++;
            }
        }

        Assert.True(successfulAttempts >= 19, "Expected at least 19 successful first-attempt registrations in a sample of 20 valid requests.");
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
