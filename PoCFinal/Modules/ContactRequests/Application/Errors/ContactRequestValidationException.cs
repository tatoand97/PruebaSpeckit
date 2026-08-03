namespace ContactRequests.Application.Errors;

public sealed class ContactRequestValidationException : Exception
{
    public ContactRequestValidationException(IReadOnlyDictionary<string, string[]> errors)
        : base("Contact request validation failed.")
    {
        Errors = errors;
    }

    public IReadOnlyDictionary<string, string[]> Errors { get; }
}
