namespace ContactRequests.Presentation.Policies;

public sealed class UnknownJsonPropertyException : Exception
{
    public UnknownJsonPropertyException()
        : base("The JSON object contains an unknown property.")
    {
    }
}
