using ContactRequests.Domain;

namespace ContactRequests.Tests.Domain;

public sealed class ContactRequestInvalidInputTests
{
    private static readonly DateTimeOffset CreatedAtUtc =
        new(2026, 7, 29, 15, 30, 0, TimeSpan.Zero);

    public static TheoryData<string?, string?, string?, string?> InvalidInputs => new()
    {
        { null, "ada@example.test", "Subject", "Message" },
        { "   ", "ada@example.test", "Subject", "Message" },
        { new string('n', 151), "ada@example.test", "Subject", "Message" },
        { "Ada", null, "Subject", "Message" },
        { "Ada", "ada example.test", "Subject", "Message" },
        { "Ada", "ada@@example.test", "Subject", "Message" },
        { "Ada", "ada@example", "Subject", "Message" },
        { "Ada", "ada@example..test", "Subject", "Message" },
        { "Ada", "ada@éxample.test", "Subject", "Message" },
        { "Ada", "ada@example.test", "\u2003", "Message" },
        { "Ada", "ada@example.test", new string('s', 201), "Message" },
        { "Ada", "ada@example.test", "Subject", "\u3000" },
        { "Ada", "ada@example.test", "Subject", new string('m', 2001) }
    };

    [Theory]
    [MemberData(nameof(InvalidInputs))]
    public void Create_rejects_invalid_input_atomically(
        string? name,
        string? email,
        string? subject,
        string? message)
    {
        Assert.Throws<ArgumentException>(() =>
            ContactRequest.Create(
                Guid.CreateVersion7(),
                name,
                email,
                subject,
                message,
                CreatedAtUtc));
    }

    [Fact]
    public void Create_rejects_empty_identifier_and_non_utc_time()
    {
        Assert.Throws<ArgumentException>(() =>
            ContactRequest.Create(
                Guid.Empty,
                "Ada",
                "ada@example.test",
                "Subject",
                "Message",
                CreatedAtUtc));

        Assert.Throws<ArgumentException>(() =>
            ContactRequest.Create(
                Guid.CreateVersion7(),
                "Ada",
                "ada@example.test",
                "Subject",
                "Message",
                CreatedAtUtc.ToOffset(TimeSpan.FromHours(-5))));
    }
}
