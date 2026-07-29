using ContactRequests.Application;
using ContactRequests.Infrastructure;
using ContactRequests.Presentation.Endpoints;
using ContactRequests.Presentation.Errors;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace ContactRequests.Presentation;

public static class DependencyInjection
{
    public static IServiceCollection AddContactRequestsModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddContactRequestsApplication();
        services.AddContactRequestsInfrastructure(configuration);

        services.AddExceptionHandler<RequestBodyTooLargeExceptionHandler>();
        services.AddExceptionHandler<UnknownJsonPropertyExceptionHandler>();
        services.AddExceptionHandler<ContactRequestValidationExceptionHandler>();
        services.AddExceptionHandler<ContactRequestIdentifierAllocationExceptionHandler>();
        services.AddExceptionHandler<ContactRequestNotFoundExceptionHandler>();

        return services;
    }

    public static IEndpointRouteBuilder MapContactRequestsModule(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapCreateContactRequest();
        endpoints.MapGetContactRequest();
        return endpoints;
    }
}
