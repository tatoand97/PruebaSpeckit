namespace ContactRequests.Application.Create;

public sealed record CreateContactRequestResult(Guid Id, DateTimeOffset CreatedAtUtc);
