using ContactRequests.Application.Errors;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace ContactRequests.Presentation.ExceptionHandling;

public sealed class ContactRequestExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ContactRequestValidationException validationException)
        {
            return false;
        }

        var details = new ValidationProblemDetails(validationException.Errors.ToDictionary(kvp => kvp.Key, kvp => kvp.Value))
        {
            Status = StatusCodes.Status400BadRequest,
            Title = "Validation failed"
        };
        details.Extensions["traceId"] = httpContext.TraceIdentifier;

        httpContext.Response.StatusCode = StatusCodes.Status400BadRequest;
        await httpContext.Response.WriteAsJsonAsync(details, cancellationToken);
        return true;
    }
}
