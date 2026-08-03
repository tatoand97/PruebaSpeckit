using ContactRequests.Application.RegisterContactRequest;
using ContactRequests.Presentation.Contracts;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Wolverine;

namespace ContactRequests.Presentation.Endpoints;

public static class RegisterContactRequestEndpoint
{
    public static IEndpointRouteBuilder MapContactRequestEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost(
                "/contact-requests",
                async (RegisterContactRequestRequest request, IMessageBus bus, CancellationToken cancellationToken) =>
                {
                    var command = new RegisterContactRequestCommand(request.Name, request.Email, request.Message);
                    var result = await bus.InvokeAsync<RegisterContactRequestResult>(command, cancellation: cancellationToken);
                    return Results.Created($"/contact-requests/{result.Id}", result);
                })
            .WithName("RegisterContactRequest")
            .WithSummary("Registers a contact request");

        return app;
    }
}
