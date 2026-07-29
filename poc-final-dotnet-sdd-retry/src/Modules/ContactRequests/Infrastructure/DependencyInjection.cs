using ContactRequests.Application.Health;
using ContactRequests.Application.Persistence;
using ContactRequests.Infrastructure.Health;
using ContactRequests.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace ContactRequests.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddContactRequestsInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("ContactRequests")
            ?? throw new InvalidOperationException(
                "ConnectionStrings:ContactRequests must be supplied externally.");

        services.AddDbContext<ContactRequestsDbContext>(options =>
            options.UseSqlServer(connectionString));
        services.AddScoped<IContactRequestRepository, SqlContactRequestRepository>();
        services.AddScoped<IContactRequestsHealthProbe, ContactRequestsHealthProbe>();
        services.AddHealthChecks()
            .AddDbContextCheck<ContactRequestsDbContext>("contact-requests-sql");

        return services;
    }
}
