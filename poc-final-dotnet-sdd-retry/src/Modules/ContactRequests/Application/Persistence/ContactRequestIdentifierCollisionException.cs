namespace ContactRequests.Application.Persistence;

public sealed class ContactRequestIdentifierCollisionException : Exception
{
    public ContactRequestIdentifierCollisionException(Exception? innerException = null)
        : base("The generated contact request identifier collided with an existing identifier.", innerException)
    {
    }
}
