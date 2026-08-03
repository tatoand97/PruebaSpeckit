namespace ContactRequests.Application.RegisterContactRequest;

public sealed record RegisterContactRequestResult(
    Guid Id,
    DateTimeOffset CreatedAt,
    string Status);
