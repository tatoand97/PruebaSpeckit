using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Orders.Application.CreateOrder;

namespace Orders.Application;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddOrdersApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssemblyContaining<CreateOrderValidator>();
        return services;
    }
}
