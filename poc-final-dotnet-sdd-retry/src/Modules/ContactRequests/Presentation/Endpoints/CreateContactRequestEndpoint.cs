using ContactRequests.Application.Create;
using ContactRequests.Presentation.Contracts;
using ContactRequests.Presentation.Policies;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Wolverine;

namespace ContactRequests.Presentation.Endpoints;

public static class CreateContactRequestEndpoint
{
    public static IEndpointRouteBuilder MapCreateContactRequest(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
                "/contact-requests",
                async (HttpContext context, IMessageBus messageBus, CancellationToken cancellationToken) =>
                {
                    var request = await StrictJsonInputPolicy.ReadCreateRequestAsync(
                        context.Request,
                        cancellationToken);

                    var result = await messageBus.InvokeAsync<CreateContactRequestResult>(
                        new CreateContactRequestCommand(
                            request.Name,
                            request.Email,
                            request.Subject,
                            request.Message),
                        cancellationToken);

                    return Results.Created(
                        $"/contact-requests/{result.Id:D}",
                        new CreateContactRequestResponse(result.Id, result.CreatedAtUtc));
                })
            .Accepts<CreateContactRequestRequest>("application/json")
            .Produces<CreateContactRequestResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status413PayloadTooLarge)
            .ProducesProblem(StatusCodes.Status500InternalServerError)
            .ProducesProblem(StatusCodes.Status503ServiceUnavailable);

        return endpoints;
    }
}
