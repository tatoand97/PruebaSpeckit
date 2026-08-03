namespace ContactRequests.Domain;

public sealed class ContactRequest
{
    public Guid Id { get; }
    public string Name { get; }
    public string Email { get; }
    public string Message { get; }
    public ContactRequestStatus Status { get; }
    public DateTimeOffset CreatedAt { get; }

    private ContactRequest(
        Guid id,
        string name,
        string email,
        string message,
        DateTimeOffset createdAt,
        ContactRequestStatus status)
    {
        Id = id;
        Name = name;
        Email = email;
        Message = message;
        CreatedAt = createdAt;
        Status = status;
    }

    public static ContactRequest Create(string name, string email, string message, DateTimeOffset? createdAt = null)
    {
        return new ContactRequest(
            Guid.NewGuid(),
            name,
            email,
            message,
            createdAt ?? DateTimeOffset.UtcNow,
            ContactRequestStatus.Pending);
    }
}
