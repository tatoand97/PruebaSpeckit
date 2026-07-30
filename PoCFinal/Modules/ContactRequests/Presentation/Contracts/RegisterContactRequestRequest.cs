namespace ContactRequests.Presentation.Contracts;

public sealed record RegisterContactRequestRequest(
    string Name,
    string Email,
    string Message);
