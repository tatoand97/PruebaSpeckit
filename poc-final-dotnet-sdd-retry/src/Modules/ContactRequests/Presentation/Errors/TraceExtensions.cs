using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Errors;

internal static class TraceExtensions
{
    public static Dictionary<string, object?> For(HttpContext httpContext) =>
        new()
        {
            ["traceId"] = httpContext.TraceIdentifier
        };
}
