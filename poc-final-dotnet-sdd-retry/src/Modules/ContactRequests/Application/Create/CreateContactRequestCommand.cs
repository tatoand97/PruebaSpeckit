namespace ContactRequests.Application.Create;

public sealed record CreateContactRequestCommand(
    string? Name,
    string? Email,
    string? Subject,
    string? Message);
