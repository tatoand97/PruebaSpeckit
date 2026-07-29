using System.Reflection;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Orders.Application;
using Orders.Application.CreateOrder;
using Orders.Infrastructure;

namespace Orders.Presentation;

public static class OrdersModule
{
    public static Assembly ApplicationAssembly => typeof(CreateOrderCommand).Assembly;

    public static IServiceCollection AddOrdersModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddOrdersApplication();
        services.AddOrdersInfrastructure(configuration);
        services.AddExceptionHandler<OrdersExceptionHandler>();

        return services;
    }

    public static IEndpointRouteBuilder MapOrdersModule(this IEndpointRouteBuilder endpoints) =>
        endpoints.MapOrdersEndpoints();
}
