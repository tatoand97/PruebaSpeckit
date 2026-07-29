using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Orders.Application;
using Orders.Infrastructure.Persistence;

namespace Orders.Infrastructure;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddOrdersInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("Orders");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "Configuration key 'ConnectionStrings:Orders' is required.");
        }

        services.AddDbContext<OrdersDbContext>(
            options => options.UseSqlServer(connectionString));
        services.AddScoped<IOrderRepository, OrderRepository>();
        services
            .AddHealthChecks()
            .AddDbContextCheck<OrdersDbContext>("orders-database");

        return services;
    }
}
