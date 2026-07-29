using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Common.Presentation;

public static class ObservabilityExtensions
{
    public static IHostApplicationBuilder AddPlatformObservability(
        this IHostApplicationBuilder builder)
    {
        builder.Services
            .AddOpenTelemetry()
            .WithTracing(tracing => tracing
                .AddAspNetCoreInstrumentation(options =>
                {
                    options.RecordException = true;
                })
                .AddHttpClientInstrumentation())
            .WithMetrics(metrics => metrics
                .AddAspNetCoreInstrumentation());

        return builder;
    }
}
