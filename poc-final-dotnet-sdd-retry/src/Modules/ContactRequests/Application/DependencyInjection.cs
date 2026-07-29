using ContactRequests.Application.Create;
using ContactRequests.Application.GetById;
using ContactRequests.Application.Health;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace ContactRequests.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddContactRequestsApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssemblyContaining<CreateContactRequestValidator>();
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<CreateContactRequestHandler>();
        services.AddScoped<GetContactRequestHandler>();
        services.AddScoped<GetContactRequestsHealthHandler>();
        return services;
    }
}
