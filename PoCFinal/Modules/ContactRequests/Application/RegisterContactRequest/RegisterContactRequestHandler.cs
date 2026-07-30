using ContactRequests.Application.Abstractions;
using ContactRequests.Application.Errors;
using ContactRequests.Domain;
using FluentValidation;

namespace ContactRequests.Application.RegisterContactRequest;

public sealed class RegisterContactRequestHandler
{
    private readonly IContactRequestRepository _repository;
    private readonly IValidator<RegisterContactRequestCommand> _validator;

    public RegisterContactRequestHandler(
        IContactRequestRepository repository,
        IValidator<RegisterContactRequestCommand> validator)
    {
        _repository = repository;
        _validator = validator;
    }

    public async Task<RegisterContactRequestResult> Handle(
        RegisterContactRequestCommand command,
        CancellationToken cancellationToken)
    {
        var validationResult = await _validator.ValidateAsync(command, cancellationToken);
        if (!validationResult.IsValid)
        {
            var errors = validationResult.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(
                    g => char.ToLowerInvariant(g.Key[0]) + g.Key[1..],
                    g => g.Select(e => e.ErrorMessage).Distinct().ToArray());

            throw new ContactRequestValidationException(errors);
        }

        var contactRequest = ContactRequest.Create(command.Name, command.Email, command.Message);
        await _repository.AddAsync(contactRequest, cancellationToken);

        return new RegisterContactRequestResult(
            contactRequest.Id,
            contactRequest.CreatedAt,
            contactRequest.Status.ToString());
    }
}
