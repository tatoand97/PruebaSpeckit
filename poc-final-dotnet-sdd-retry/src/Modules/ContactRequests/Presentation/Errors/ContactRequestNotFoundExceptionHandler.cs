using ContactRequests.Application.GetById;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Errors;

public sealed class ContactRequestNotFoundExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ContactRequestNotFoundException)
        {
            return false;
        }

        var result = Results.Problem(
            statusCode: StatusCodes.Status404NotFound,
            title: "Contact request not found",
            detail: "No contact request exactly matches the supplied identifier.",
            type: "https://httpstatuses.com/404",
            extensions: TraceExtensions.For(httpContext));

        await result.ExecuteAsync(httpContext);
        return true;
    }
}
