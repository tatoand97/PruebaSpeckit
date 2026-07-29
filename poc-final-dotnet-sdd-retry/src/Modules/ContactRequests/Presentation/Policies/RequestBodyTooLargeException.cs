namespace ContactRequests.Presentation.Policies;

public sealed class RequestBodyTooLargeException : Exception
{
    public RequestBodyTooLargeException()
        : base("The request body exceeds the configured size limit.")
    {
    }
}
