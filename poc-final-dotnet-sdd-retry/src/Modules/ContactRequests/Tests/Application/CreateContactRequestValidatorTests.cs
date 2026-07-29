using ContactRequests.Application.Create;

namespace ContactRequests.Tests.Application;

public sealed class CreateContactRequestValidatorTests
{
    private readonly CreateContactRequestValidator validator = new();

    [Fact]
    public async Task Validator_accumulates_all_missing_field_errors()
    {
        var result = await validator.ValidateAsync(
            new CreateContactRequestCommand(null, null, null, null),
            CancellationToken.None);

        Assert.False(result.IsValid);
        Assert.Equal(4, result.Errors.Count);
        Assert.Equal(
            ["Name", "Email", "Subject", "Message"],
            result.Errors.Select(error => error.PropertyName));
    }

    [Fact]
    public async Task Validator_accepts_inclusive_limits_and_unicode_scalars()
    {
        var command = new CreateContactRequestCommand(
            string.Concat(Enumerable.Repeat("😀", 150)),
            new string('a', 307) + "@example.test",
            new string('s', 200),
            new string('m', 2000));

        var result = await validator.ValidateAsync(
            command,
            CancellationToken.None);

        Assert.True(result.IsValid);
    }

    [Theory]
    [InlineData(" ", "ada@example.test", "Subject", "Message")]
    [InlineData("Ada", "invalid", "Subject", "Message")]
    public async Task Validator_rejects_whitespace_and_invalid_email(
        string name,
        string email,
        string subject,
        string message)
    {
        var result = await validator.ValidateAsync(
            new CreateContactRequestCommand(name, email, subject, message),
            CancellationToken.None);

        Assert.False(result.IsValid);
    }

    [Fact]
    public async Task Validator_reports_each_exceeded_limit()
    {
        var result = await validator.ValidateAsync(
            new CreateContactRequestCommand(
                new string('n', 151),
                "ada@example.test",
                new string('s', 201),
                new string('m', 2001)),
            CancellationToken.None);

        Assert.Equal(3, result.Errors.Count);
    }
}
