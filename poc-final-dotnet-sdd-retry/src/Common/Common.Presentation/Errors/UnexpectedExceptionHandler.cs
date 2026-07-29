using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace Common.Presentation.Errors;

public sealed class UnexpectedExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var result = Results.Problem(
            statusCode: StatusCodes.Status500InternalServerError,
            title: "Unexpected server error",
            type: "https://httpstatuses.com/500",
            extensions: new Dictionary<string, object?>
            {
                ["traceId"] = httpContext.TraceIdentifier
            });

        await result.ExecuteAsync(httpContext);
        return true;
    }
}
