using ContactRequests.Application.RegisterContactRequest;

namespace ContactRequests.Test.Application;

public sealed class RegisterContactRequestValidatorTests
{
    private readonly RegisterContactRequestValidator _validator = new();

    [Theory]
    [InlineData("", "a@example.com", "1234567890")]
    [InlineData("A", "invalid-email", "1234567890")]
    [InlineData("A", "a@example.com", "short")]
    public void Validate_ReturnsInvalid_ForInvalidPayload(string name, string email, string message)
    {
        var result = _validator.Validate(new RegisterContactRequestCommand(name, email, message));
        Assert.False(result.IsValid);
    }

    [Theory]
    [InlineData("User", "user@example.com", 10)]
    [InlineData("User", "user@example.com", 1000)]
    public void Validate_ReturnsValid_ForBoundaryMessageLength(string name, string email, int length)
    {
        var message = new string('a', length);
        var result = _validator.Validate(new RegisterContactRequestCommand(name, email, message));
        Assert.True(result.IsValid);
    }
}
