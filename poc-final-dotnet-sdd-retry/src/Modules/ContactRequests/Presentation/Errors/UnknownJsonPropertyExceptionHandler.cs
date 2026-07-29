using ContactRequests.Presentation.Policies;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Errors;

public sealed class UnknownJsonPropertyExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not UnknownJsonPropertyException)
        {
            return false;
        }

        var extensions = TraceExtensions.For(httpContext);
        extensions["errors"] = new Dictionary<string, string[]>
        {
            ["$"] = ["Unknown properties are not allowed."]
        };

        var result = Results.Problem(
            statusCode: StatusCodes.Status400BadRequest,
            title: "One or more input fields are invalid",
            type: "https://httpstatuses.com/400",
            extensions: extensions);

        await result.ExecuteAsync(httpContext);
        return true;
    }
}
