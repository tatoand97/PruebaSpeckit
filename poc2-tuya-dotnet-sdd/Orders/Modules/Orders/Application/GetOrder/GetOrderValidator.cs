using FluentValidation;

namespace Orders.Application.GetOrder;

public sealed class GetOrderValidator : AbstractValidator<GetOrderQuery>
{
    public GetOrderValidator()
    {
        RuleFor(query => query.OrderId)
            .Must(BeCanonicalOrderId)
            .WithMessage("OrderId must be a non-empty GUID in canonical format.");
    }

    private static bool BeCanonicalOrderId(string? value) =>
        Guid.TryParseExact(value, "D", out var parsed) && parsed != Guid.Empty;
}
