using ContactRequests.Presentation.Policies;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Errors;

public sealed class RequestBodyTooLargeExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not RequestBodyTooLargeException)
        {
            return false;
        }

        var result = Results.Problem(
            statusCode: StatusCodes.Status413PayloadTooLarge,
            title: "Request body too large",
            detail: "The request body must not exceed 8192 bytes.",
            type: "https://httpstatuses.com/413",
            extensions: TraceExtensions.For(httpContext));

        await result.ExecuteAsync(httpContext);
        return true;
    }
}
