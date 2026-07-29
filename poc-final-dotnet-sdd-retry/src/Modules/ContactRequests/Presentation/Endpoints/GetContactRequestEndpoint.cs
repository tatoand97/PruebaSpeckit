using ContactRequests.Application.GetById;
using ContactRequests.Presentation.Contracts;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Wolverine;

namespace ContactRequests.Presentation.Endpoints;

public static class GetContactRequestEndpoint
{
    public static IEndpointRouteBuilder MapGetContactRequest(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/contact-requests/{contactRequestId}",
                async (
                    string contactRequestId,
                    IMessageBus messageBus,
                    CancellationToken cancellationToken) =>
                {
                    var result = await messageBus.InvokeAsync<GetContactRequestResult>(
                        new GetContactRequestQuery(contactRequestId),
                        cancellationToken);

                    return Results.Ok(new ContactRequestResponse(
                        result.Id,
                        result.Name,
                        result.Email,
                        result.Subject,
                        result.Message,
                        result.CreatedAtUtc));
                })
            .Produces<ContactRequestResponse>(StatusCodes.Status200OK)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status500InternalServerError);

        return endpoints;
    }
}
