using ContactRequests.Domain;
using FluentValidation;

namespace ContactRequests.Application.Create;

public sealed class CreateContactRequestValidator : AbstractValidator<CreateContactRequestCommand>
{
    public CreateContactRequestValidator()
    {
        RuleFor(command => command.Name)
            .Custom((value, context) =>
                ValidateUnicodeField(
                    value,
                    ContactRequestRules.NameMaximumScalarLength,
                    "Name",
                    context));

        RuleFor(command => command.Email)
            .Custom((value, context) =>
            {
                if (string.IsNullOrEmpty(value))
                {
                    context.AddFailure("Email is required.");
                }
                else if (!ContactRequestRules.IsValidEmail(value))
                {
                    context.AddFailure("Email must satisfy the required ASCII format.");
                }
            });

        RuleFor(command => command.Subject)
            .Custom((value, context) =>
                ValidateUnicodeField(
                    value,
                    ContactRequestRules.SubjectMaximumScalarLength,
                    "Subject",
                    context));

        RuleFor(command => command.Message)
            .Custom((value, context) =>
                ValidateUnicodeField(
                    value,
                    ContactRequestRules.MessageMaximumScalarLength,
                    "Message",
                    context));
    }

    private static void ValidateUnicodeField(
        string? value,
        int maximum,
        string displayName,
        ValidationContext<CreateContactRequestCommand> context)
    {
        var normalized = ContactRequestRules.TrimUnicodeWhiteSpace(value);
        var length = ContactRequestRules.CountUnicodeScalars(normalized);

        if (length == 0)
        {
            context.AddFailure($"{displayName} is required.");
        }
        else if (length > maximum)
        {
            context.AddFailure($"{displayName} must contain at most {maximum} Unicode scalar values.");
        }
    }
}
