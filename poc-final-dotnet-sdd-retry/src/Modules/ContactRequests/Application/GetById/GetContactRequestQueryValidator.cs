using FluentValidation;

namespace ContactRequests.Application.GetById;

public sealed class GetContactRequestQueryValidator : AbstractValidator<GetContactRequestQuery>
{
    public const string ExactIdentifierNotFoundErrorCode = "ExactIdentifierNotFound";

    public GetContactRequestQueryValidator()
    {
        RuleFor(query => query.ContactRequestId)
            .Must(value => Guid.TryParseExact(value, "D", out var id) && id != Guid.Empty)
            .WithMessage("No contact request exactly matches the supplied identifier.")
            .WithErrorCode(ExactIdentifierNotFoundErrorCode);
    }
}
