using FluentValidation;

namespace ContactRequests.Application.RegisterContactRequest;

public sealed class RegisterContactRequestValidator : AbstractValidator<RegisterContactRequestCommand>
{
    public RegisterContactRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100);

        RuleFor(x => x.Email)
            .NotEmpty()
            .Must(BeValidEmail)
            .WithMessage("Email must contain one @, a non-empty local part, a domain with at least one dot, and no spaces.");

        RuleFor(x => x.Message)
            .NotEmpty()
            .MinimumLength(10)
            .MaximumLength(1000);
    }

    private static bool BeValidEmail(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Contains(' '))
        {
            return false;
        }

        var atIndex = value.IndexOf('@');
        if (atIndex <= 0 || atIndex != value.LastIndexOf('@') || atIndex == value.Length - 1)
        {
            return false;
        }

        var domain = value[(atIndex + 1)..];
        return domain.Contains('.', StringComparison.Ordinal);
    }
}
