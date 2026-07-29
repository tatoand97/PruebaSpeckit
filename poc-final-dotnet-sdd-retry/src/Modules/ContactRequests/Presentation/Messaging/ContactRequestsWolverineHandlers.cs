using ContactRequests.Application.Create;
using ContactRequests.Application.GetById;
using ContactRequests.Application.Health;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Wolverine;
using Wolverine.Runtime;
using Wolverine.Runtime.Handlers;

namespace ContactRequests.Presentation.Messaging;

public static class ContactRequestsWolverineHandlers
{
    public static WolverineOptions UseContactRequestsMediatorHandlers(
        this WolverineOptions options)
    {
        options.Discovery.DisableConventionalDiscovery();
        options.AddMessageHandler(new CreateMessageHandler());
        options.AddMessageHandler(new GetByIdMessageHandler());
        options.AddMessageHandler(new HealthMessageHandler());
        return options;
    }

    private sealed class CreateMessageHandler : MessageHandler<CreateContactRequestCommand>
    {
        protected override async Task HandleAsync(
            CreateContactRequestCommand message,
            MessageContext context,
            CancellationToken cancellationToken)
        {
            await using var scope = context.Runtime.Services.CreateAsyncScope();
            var services = scope.ServiceProvider;
            var handler = services.GetRequiredService<CreateContactRequestHandler>();
            var validator = services.GetRequiredService<IValidator<CreateContactRequestCommand>>();

            await CreateContactRequestHandler.ValidateAsync(
                message,
                validator,
                cancellationToken);
            var result = await handler.Handle(message, cancellationToken);
            await context.RespondToSenderAsync(result);
        }
    }

    private sealed class GetByIdMessageHandler : MessageHandler<GetContactRequestQuery>
    {
        protected override async Task HandleAsync(
            GetContactRequestQuery message,
            MessageContext context,
            CancellationToken cancellationToken)
        {
            await using var scope = context.Runtime.Services.CreateAsyncScope();
            var services = scope.ServiceProvider;
            var handler = services.GetRequiredService<GetContactRequestHandler>();
            var validator = services.GetRequiredService<IValidator<GetContactRequestQuery>>();

            await GetContactRequestHandler.ValidateAsync(message, validator, cancellationToken);
            var result = await handler.Handle(message, cancellationToken);
            await context.RespondToSenderAsync(result);
        }
    }

    private sealed class HealthMessageHandler : MessageHandler<GetContactRequestsHealthQuery>
    {
        protected override async Task HandleAsync(
            GetContactRequestsHealthQuery message,
            MessageContext context,
            CancellationToken cancellationToken)
        {
            await using var scope = context.Runtime.Services.CreateAsyncScope();
            var handler = scope.ServiceProvider.GetRequiredService<GetContactRequestsHealthHandler>();
            var result = await handler.Handle(message, cancellationToken);
            await context.RespondToSenderAsync(result);
        }
    }
}
