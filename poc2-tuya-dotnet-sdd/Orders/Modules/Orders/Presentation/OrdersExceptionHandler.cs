using System.Diagnostics;
using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Orders.Application;
using Orders.Domain;

namespace Orders.Presentation;

public sealed class OrdersExceptionHandler(IProblemDetailsService problemDetailsService)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var problem = exception switch
        {
            ValidationException validation => ValidationProblem(httpContext, validation),
            DuplicateProductException duplicate => DuplicateProblem(httpContext, duplicate),
            OrderNotFoundException notFound => NotFoundProblem(httpContext, notFound),
            BadHttpRequestException => BadRequestProblem(httpContext),
            _ => null,
        };

        if (problem is null)
        {
            return false;
        }

        httpContext.Response.StatusCode = problem.Status!.Value;
        problem.Extensions["traceId"] = Activity.Current?.Id ?? httpContext.TraceIdentifier;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = problem,
            Exception = exception,
        });
    }

    private static ProblemDetails ValidationProblem(
        HttpContext context,
        ValidationException exception)
    {
        var errors = exception.Errors
            .GroupBy(error => error.PropertyName, StringComparer.Ordinal)
            .ToDictionary(
                group => group.Key,
                group => group.Select(error => error.ErrorMessage).Distinct().ToArray(),
                StringComparer.Ordinal);

        return CreateBadRequest(context, "One or more validation errors occurred.", errors);
    }

    private static ProblemDetails DuplicateProblem(
        HttpContext context,
        DuplicateProductException exception) =>
        CreateBadRequest(
            context,
            "The order contains a duplicate product.",
            new Dictionary<string, string[]>(StringComparer.Ordinal)
            {
                ["Items"] = [$"Product '{exception.ProductId}' appears more than once."],
            });

    private static ProblemDetails BadRequestProblem(HttpContext context) =>
        CreateBadRequest(
            context,
            "The request body or route is invalid.",
            new Dictionary<string, string[]>(StringComparer.Ordinal)
            {
                ["Request"] = ["The request could not be parsed."],
            });

    private static ProblemDetails CreateBadRequest(
        HttpContext context,
        string title,
        IReadOnlyDictionary<string, string[]> errors)
    {
        var problem = new ProblemDetails
        {
            Type = "https://httpstatuses.com/400",
            Title = title,
            Status = StatusCodes.Status400BadRequest,
            Detail = "Correct the indicated values and submit the request again.",
            Instance = context.Request.Path,
        };
        problem.Extensions["errors"] = errors;

        return problem;
    }

    private static ProblemDetails NotFoundProblem(
        HttpContext context,
        OrderNotFoundException exception) =>
        new()
        {
            Type = "https://httpstatuses.com/404",
            Title = "Order not found.",
            Status = StatusCodes.Status404NotFound,
            Detail = $"No order was found for identifier '{exception.OrderId}'.",
            Instance = context.Request.Path,
        };
}
