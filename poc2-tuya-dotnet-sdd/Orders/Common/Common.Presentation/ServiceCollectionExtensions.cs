using Microsoft.Extensions.DependencyInjection;

namespace Common.Presentation;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCommonPresentation(this IServiceCollection services)
    {
        services.AddProblemDetails();
        services.AddExceptionHandler<GlobalExceptionHandler>();

        return services;
    }
}
