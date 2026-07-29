namespace ContactRequests.Presentation.Contracts;

public sealed record ContactRequestResponse(
    Guid Id,
    string Name,
    string Email,
    string Subject,
    string Message,
    DateTimeOffset CreatedAtUtc);
