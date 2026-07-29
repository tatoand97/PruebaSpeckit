using ContactRequests.Application.GetById;
using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Errors;

public sealed class ContactRequestValidationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ValidationException validationException)
        {
            return false;
        }

        if (validationException.Errors.Any(error =>
            error.ErrorCode == GetContactRequestQueryValidator.ExactIdentifierNotFoundErrorCode))
        {
            var notFound = Results.Problem(
                statusCode: StatusCodes.Status404NotFound,
                title: "Contact request not found",
                detail: "No contact request exactly matches the supplied identifier.",
                type: "https://httpstatuses.com/404",
                extensions: TraceExtensions.For(httpContext));

            await notFound.ExecuteAsync(httpContext);
            return true;
        }

        var errors = validationException.Errors
            .GroupBy(error => ToCamelCase(error.PropertyName))
            .ToDictionary(
                group => group.Key,
                group => group.Select(error => error.ErrorMessage).Distinct().ToArray());

        var extensions = TraceExtensions.For(httpContext);
        extensions["errors"] = errors;

        var result = Results.Problem(
            statusCode: StatusCodes.Status400BadRequest,
            title: "One or more input fields are invalid",
            type: "https://httpstatuses.com/400",
            extensions: extensions);

        await result.ExecuteAsync(httpContext);
        return true;
    }

    private static string ToCamelCase(string propertyName)
    {
        if (string.IsNullOrEmpty(propertyName) || propertyName == "$")
        {
            return "$";
        }

        return char.ToLowerInvariant(propertyName[0]) + propertyName[1..];
    }
}
