namespace ContactRequests.Application.Create;

public sealed class ContactRequestIdentifierAllocationException : Exception
{
    public ContactRequestIdentifierAllocationException()
        : base("A unique contact request identifier could not be allocated.")
    {
    }
}
