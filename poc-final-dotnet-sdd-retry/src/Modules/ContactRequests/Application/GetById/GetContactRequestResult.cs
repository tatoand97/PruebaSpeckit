namespace ContactRequests.Application.GetById;

public sealed record GetContactRequestResult(
    Guid Id,
    string Name,
    string Email,
    string Subject,
    string Message,
    DateTimeOffset CreatedAtUtc);
