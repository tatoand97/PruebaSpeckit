using ContactRequests.Domain;

namespace ContactRequests.Tests.Domain;

public sealed class ContactRequestTests
{
    private static readonly DateTimeOffset CreatedAtUtc =
        new(2026, 7, 29, 15, 30, 0, TimeSpan.Zero);

    [Fact]
    public void Create_accepts_inclusive_scalar_boundaries()
    {
        var maximumName = RepeatRune("😀", ContactRequestRules.NameMaximumScalarLength);
        var maximumSubject = RepeatRune("𐐀", ContactRequestRules.SubjectMaximumScalarLength);
        var maximumMessage = RepeatRune("🎉", ContactRequestRules.MessageMaximumScalarLength);

        var request = ContactRequest.Create(
            Guid.CreateVersion7(),
            maximumName,
            "ada@example.test",
            maximumSubject,
            maximumMessage,
            CreatedAtUtc);

        Assert.Equal(ContactRequestRules.NameMaximumScalarLength, request.Name.EnumerateRunes().Count());
        Assert.Equal(ContactRequestRules.SubjectMaximumScalarLength, request.Subject.EnumerateRunes().Count());
        Assert.Equal(ContactRequestRules.MessageMaximumScalarLength, request.Message.EnumerateRunes().Count());
    }

    [Fact]
    public void Create_trims_ascii_and_unicode_whitespace_but_preserves_email_exactly()
    {
        const string email = "Ada+Tag@Example.test";

        var request = ContactRequest.Create(
            Guid.CreateVersion7(),
            "\u2003  Ada Lovelace\u3000",
            email,
            "\t Subject \r\n",
            "\u2028Synthetic message\u205F",
            CreatedAtUtc);

        Assert.Equal("Ada Lovelace", request.Name);
        Assert.Equal(email, request.Email);
        Assert.Equal("Subject", request.Subject);
        Assert.Equal("Synthetic message", request.Message);
    }

    [Fact]
    public void Aggregate_state_is_not_publicly_mutable()
    {
        var writableProperties = typeof(ContactRequest)
            .GetProperties()
            .Where(property => property.SetMethod?.IsPublic == true);

        Assert.Empty(writableProperties);
    }

    [Fact]
    public void Create_accepts_one_scalar_for_each_trimmed_text_field()
    {
        var request = ContactRequest.Create(
            Guid.CreateVersion7(),
            "😀",
            "a@b.test",
            "x",
            "y",
            CreatedAtUtc);

        Assert.Equal("😀", request.Name);
    }

    private static string RepeatRune(string value, int count) =>
        string.Concat(Enumerable.Repeat(value, count));
}
