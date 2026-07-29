namespace ContactRequests.Application.GetById;

public sealed class ContactRequestNotFoundException : Exception
{
    public ContactRequestNotFoundException()
        : base("No contact request exactly matches the supplied identifier.")
    {
    }
}
