using ContactRequests.Application.Persistence;
using ContactRequests.Domain;
using FluentValidation;

namespace ContactRequests.Application.Create;

public sealed class CreateContactRequestHandler(
    IContactRequestRepository repository,
    TimeProvider timeProvider)
{
    public static Task ValidateAsync(
        CreateContactRequestCommand command,
        IValidator<CreateContactRequestCommand> validator,
        CancellationToken cancellationToken) =>
        validator.ValidateAndThrowAsync(command, cancellationToken);

    public async Task<CreateContactRequestResult> Handle(
        CreateContactRequestCommand command,
        CancellationToken cancellationToken)
    {
        var createdAtUtc = timeProvider.GetUtcNow();

        for (var attempt = 0; attempt < 3; attempt++)
        {
            var contactRequest = ContactRequest.Create(
                Guid.CreateVersion7(),
                command.Name,
                command.Email,
                command.Subject,
                command.Message,
                createdAtUtc);

            try
            {
                await repository.AddAsync(contactRequest, cancellationToken);
                return new CreateContactRequestResult(contactRequest.Id, createdAtUtc);
            }
            catch (ContactRequestIdentifierCollisionException) when (attempt < 2)
            {
            }
            catch (ContactRequestIdentifierCollisionException)
            {
                break;
            }
        }

        throw new ContactRequestIdentifierAllocationException();
    }
}
