using Common.Presentation.Errors;
using Microsoft.Extensions.DependencyInjection;

namespace Common.Presentation;

public static class DependencyInjection
{
    public static IServiceCollection AddCommonPresentation(this IServiceCollection services)
    {
        services.AddExceptionHandler<UnexpectedExceptionHandler>();
        return services;
    }
}
