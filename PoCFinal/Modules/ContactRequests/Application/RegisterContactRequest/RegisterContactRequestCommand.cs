namespace ContactRequests.Application.RegisterContactRequest;

public sealed record RegisterContactRequestCommand(
    string Name,
    string Email,
    string Message);
