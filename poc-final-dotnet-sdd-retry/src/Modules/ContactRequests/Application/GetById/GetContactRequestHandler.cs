using ContactRequests.Application.Persistence;
using FluentValidation;

namespace ContactRequests.Application.GetById;

public sealed class GetContactRequestHandler(
    IContactRequestRepository repository)
{
    public static Task ValidateAsync(
        GetContactRequestQuery query,
        IValidator<GetContactRequestQuery> validator,
        CancellationToken cancellationToken) =>
        validator.ValidateAndThrowAsync(query, cancellationToken);

    public async Task<GetContactRequestResult> Handle(
        GetContactRequestQuery query,
        CancellationToken cancellationToken)
    {
        var id = Guid.ParseExact(query.ContactRequestId!, "D");
        var contactRequest = await repository.GetByIdAsync(id, cancellationToken)
            ?? throw new ContactRequestNotFoundException();

        return new GetContactRequestResult(
            contactRequest.Id,
            contactRequest.Name,
            contactRequest.Email,
            contactRequest.Subject,
            contactRequest.Message,
            contactRequest.CreatedAtUtc);
    }
}
