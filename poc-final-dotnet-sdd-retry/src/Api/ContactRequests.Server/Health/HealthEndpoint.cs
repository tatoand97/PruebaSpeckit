using ContactRequests.Application.Health;
using Wolverine;

namespace ContactRequests.Server.Health;

public static class HealthEndpoint
{
    public static IEndpointRouteBuilder MapContactRequestsHealth(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/health",
                async (IMessageBus messageBus, CancellationToken cancellationToken) =>
                {
                    var result = await messageBus.InvokeAsync<GetContactRequestsHealthResult>(
                        new GetContactRequestsHealthQuery(),
                        cancellationToken);

                    return result.Status == "Healthy"
                        ? Results.Ok(result)
                        : Results.Json(
                            result,
                            statusCode: StatusCodes.Status503ServiceUnavailable);
                })
            .Produces<GetContactRequestsHealthResult>(StatusCodes.Status200OK)
            .Produces<GetContactRequestsHealthResult>(StatusCodes.Status503ServiceUnavailable);

        return endpoints;
    }
}
