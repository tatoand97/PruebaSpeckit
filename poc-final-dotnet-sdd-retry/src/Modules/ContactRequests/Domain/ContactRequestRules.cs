using System.Text;

namespace ContactRequests.Domain;

public static class ContactRequestRules
{
    public const int NameMaximumScalarLength = 150;
    public const int EmailMaximumLength = 320;
    public const int SubjectMaximumScalarLength = 200;
    public const int MessageMaximumScalarLength = 2000;

    public static string TrimUnicodeWhiteSpace(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var start = 0;
        while (start < value.Length)
        {
            var status = Rune.DecodeFromUtf16(value.AsSpan(start), out var rune, out var consumed);
            if (status != System.Buffers.OperationStatus.Done || !Rune.IsWhiteSpace(rune))
            {
                break;
            }

            start += consumed;
        }

        var end = value.Length;
        while (end > start)
        {
            var status = Rune.DecodeLastFromUtf16(value.AsSpan(0, end), out var rune, out var consumed);
            if (status != System.Buffers.OperationStatus.Done || !Rune.IsWhiteSpace(rune))
            {
                break;
            }

            end -= consumed;
        }

        return value[start..end];
    }

    public static int CountUnicodeScalars(string value) => value.EnumerateRunes().Count();

    public static bool HasValidScalarLength(string value, int maximum) =>
        CountUnicodeScalars(value) is >= 1 && CountUnicodeScalars(value) <= maximum;

    public static bool IsValidEmail(string? email)
    {
        if (string.IsNullOrEmpty(email) || email.Length > EmailMaximumLength)
        {
            return false;
        }

        if (email.Any(character => character is < '\u0021' or > '\u007E'))
        {
            return false;
        }

        var atIndex = email.IndexOf('@');
        if (atIndex <= 0 || atIndex != email.LastIndexOf('@') || atIndex == email.Length - 1)
        {
            return false;
        }

        var domain = email[(atIndex + 1)..];
        return domain.Contains('.', StringComparison.Ordinal)
            && domain.Split('.').All(label => label.Length > 0);
    }
}
