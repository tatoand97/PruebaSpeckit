namespace ContactRequests.Presentation.Contracts;

public sealed record CreateContactRequestRequest(
    string? Name,
    string? Email,
    string? Subject,
    string? Message);

public sealed record CreateContactRequestResponse(Guid Id, DateTimeOffset CreatedAtUtc);
