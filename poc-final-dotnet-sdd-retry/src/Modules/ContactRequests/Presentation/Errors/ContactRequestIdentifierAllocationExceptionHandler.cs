using ContactRequests.Application.Create;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Errors;

public sealed class ContactRequestIdentifierAllocationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ContactRequestIdentifierAllocationException)
        {
            return false;
        }

        httpContext.Response.Headers.RetryAfter = "1";
        var result = Results.Problem(
            statusCode: StatusCodes.Status503ServiceUnavailable,
            title: "Contact request could not be created",
            detail: "A unique identifier could not be allocated. Retry the request.",
            type: "https://httpstatuses.com/503",
            extensions: TraceExtensions.For(httpContext));

        await result.ExecuteAsync(httpContext);
        return true;
    }
}
