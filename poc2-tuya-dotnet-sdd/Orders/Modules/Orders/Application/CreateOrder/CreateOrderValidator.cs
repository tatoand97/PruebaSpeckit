using FluentValidation;

namespace Orders.Application.CreateOrder;

public sealed class CreateOrderValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderValidator()
    {
        RuleFor(command => command.CustomerId)
            .Must(ContainsNonWhitespace)
            .WithMessage("CustomerId must contain at least one non-whitespace character.");

        RuleFor(command => command.Items)
            .NotNull()
            .WithMessage("Items is required.")
            .NotEmpty()
            .WithMessage("At least one item is required.");

        RuleForEach(command => command.Items)
            .ChildRules(item =>
            {
                item.RuleFor(value => value.ProductId)
                    .Must(ContainsNonWhitespace)
                    .WithMessage(
                        "ProductId must contain at least one non-whitespace character.");

                item.RuleFor(value => value.Quantity)
                    .GreaterThan(0)
                    .WithMessage("Quantity must be between 1 and 2147483647.");
            });
    }

    private static bool ContainsNonWhitespace(string? value) =>
        value is not null && value.Any(character => !char.IsWhiteSpace(character));
}
