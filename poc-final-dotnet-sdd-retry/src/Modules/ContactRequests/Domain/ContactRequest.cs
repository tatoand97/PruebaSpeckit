namespace ContactRequests.Domain;

public sealed class ContactRequest
{
    private ContactRequest()
    {
        Name = null!;
        Email = null!;
        Subject = null!;
        Message = null!;
    }

    private ContactRequest(
        Guid id,
        string name,
        string email,
        string subject,
        string message,
        DateTimeOffset createdAtUtc)
    {
        Id = id;
        Name = name;
        Email = email;
        Subject = subject;
        Message = message;
        CreatedAtUtc = createdAtUtc;
    }

    public Guid Id { get; private set; }

    public string Name { get; private set; }

    public string Email { get; private set; }

    public string Subject { get; private set; }

    public string Message { get; private set; }

    public DateTimeOffset CreatedAtUtc { get; private set; }

    public static ContactRequest Create(
        Guid id,
        string? name,
        string? email,
        string? subject,
        string? message,
        DateTimeOffset createdAtUtc)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("A generated identifier is required.", nameof(id));
        }

        if (createdAtUtc.Offset != TimeSpan.Zero)
        {
            throw new ArgumentException("The creation instant must be UTC.", nameof(createdAtUtc));
        }

        var normalizedName = ContactRequestRules.TrimUnicodeWhiteSpace(name);
        var normalizedSubject = ContactRequestRules.TrimUnicodeWhiteSpace(subject);
        var normalizedMessage = ContactRequestRules.TrimUnicodeWhiteSpace(message);

        EnsureScalarLength(normalizedName, ContactRequestRules.NameMaximumScalarLength, nameof(name));
        EnsureScalarLength(normalizedSubject, ContactRequestRules.SubjectMaximumScalarLength, nameof(subject));
        EnsureScalarLength(normalizedMessage, ContactRequestRules.MessageMaximumScalarLength, nameof(message));

        if (!ContactRequestRules.IsValidEmail(email))
        {
            throw new ArgumentException("Email does not satisfy the contact request policy.", nameof(email));
        }

        return new ContactRequest(
            id,
            normalizedName,
            email!,
            normalizedSubject,
            normalizedMessage,
            createdAtUtc);
    }

    private static void EnsureScalarLength(string value, int maximum, string parameterName)
    {
        if (!ContactRequestRules.HasValidScalarLength(value, maximum))
        {
            throw new ArgumentException("The value does not satisfy its scalar-length policy.", parameterName);
        }
    }
}
