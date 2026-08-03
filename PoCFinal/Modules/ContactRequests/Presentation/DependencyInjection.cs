using ContactRequests.Application.Abstractions;
using ContactRequests.Infrastructure.Repositories;
using ContactRequests.Presentation.Endpoints;
using ContactRequests.Presentation.ExceptionHandling;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace ContactRequests.Presentation;

public static class DependencyInjection
{
    public static IServiceCollection AddContactRequestsModule(this IServiceCollection services)
    {
        services.AddScoped<IContactRequestRepository, EfContactRequestRepository>();
        services.AddExceptionHandler<ContactRequestExceptionHandler>();
        return services;
    }

    public static IEndpointRouteBuilder MapContactRequestsModule(this IEndpointRouteBuilder app)
    {
        app.MapContactRequestEndpoints();
        return app;
    }
}
