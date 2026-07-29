using Microsoft.Extensions.DependencyInjection;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Common.Infrastructure.Observability;

public static class ObservabilityExtensions
{
    public static IServiceCollection AddContactRequestsObservability(this IServiceCollection services)
    {
        services
            .AddOpenTelemetry()
            .WithTracing(tracing => tracing
                .AddAspNetCoreInstrumentation(options =>
                {
                    options.RecordException = false;
                    options.Filter = context => !context.Request.Path.StartsWithSegments("/health");
                })
                .AddSource("ContactRequests.EntityFrameworkCore"))
            .WithMetrics(metrics => metrics.AddAspNetCoreInstrumentation());

        return services;
    }
}
