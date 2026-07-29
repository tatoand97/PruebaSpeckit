using System.Text;
using ContactRequests.Presentation.Errors;
using ContactRequests.Presentation.Policies;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

namespace ContactRequests.Tests.Presentation;

public sealed class CreateContactRequestHttpPolicyTests
{
    [Fact]
    public async Task Size_policy_accepts_exactly_8192_bytes()
    {
        var context = CreateContext(new byte[8192]);

        var body = await RequestBodySizePolicy.ReadBodyAsync(
            context.Request,
            CancellationToken.None);

        Assert.Equal(8192, body.Length);
    }

    [Fact]
    public async Task Size_policy_rejects_8193_bytes_before_mediation()
    {
        var context = CreateContext(new byte[8193]);
        var mediatorInvoked = false;

        await Assert.ThrowsAsync<RequestBodyTooLargeException>(async () =>
        {
            await RequestBodySizePolicy.ReadBodyAsync(
                context.Request,
                CancellationToken.None);
            mediatorInvoked = true;
        });

        Assert.False(mediatorInvoked);
    }

    [Fact]
    public async Task Strict_policy_rejects_unknown_property_before_mediation()
    {
        var json = """
            {
              "name": "Ada",
              "email": "ada@example.test",
              "subject": "Subject",
              "message": "Synthetic",
              "extra": "not allowed"
            }
            """;
        var context = CreateContext(Encoding.UTF8.GetBytes(json));
        var mediatorInvoked = false;

        await Assert.ThrowsAsync<UnknownJsonPropertyException>(async () =>
        {
            await StrictJsonInputPolicy.ReadCreateRequestAsync(
                context.Request,
                CancellationToken.None);
            mediatorInvoked = true;
        });

        Assert.False(mediatorInvoked);
    }

    [Fact]
    public async Task Strict_policy_is_camel_case_and_case_sensitive()
    {
        var json = """
            {"Name":"Ada","email":"ada@example.test","subject":"Subject","message":"Synthetic"}
            """;
        var context = CreateContext(Encoding.UTF8.GetBytes(json));

        await Assert.ThrowsAsync<UnknownJsonPropertyException>(() =>
            StrictJsonInputPolicy.ReadCreateRequestAsync(
                context.Request,
                CancellationToken.None));
    }

    [Fact]
    public async Task Validation_handler_returns_safe_400_without_rejected_values()
    {
        var context = CreateWritableContext();
        var exception = new ValidationException(
            [new ValidationFailure("Email", "Email must satisfy the required ASCII format.")
            {
                AttemptedValue = "real-person@example.com"
            }]);
        var handler = new ContactRequestValidationExceptionHandler();

        var handled = await handler.TryHandleAsync(
            context,
            exception,
            CancellationToken.None);

        context.Response.Body.Position = 0;
        var response = await new StreamReader(context.Response.Body).ReadToEndAsync(
            CancellationToken.None);

        Assert.True(handled);
        Assert.Equal(StatusCodes.Status400BadRequest, context.Response.StatusCode);
        Assert.Contains("\"errors\"", response, StringComparison.Ordinal);
        Assert.Contains("\"traceId\"", response, StringComparison.Ordinal);
        Assert.DoesNotContain("real-person@example.com", response, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Size_handler_returns_safe_413()
    {
        var context = CreateWritableContext();
        var handler = new RequestBodyTooLargeExceptionHandler();

        var handled = await handler.TryHandleAsync(
            context,
            new RequestBodyTooLargeException(),
            CancellationToken.None);

        Assert.True(handled);
        Assert.Equal(StatusCodes.Status413PayloadTooLarge, context.Response.StatusCode);
        Assert.Equal("application/problem+json", context.Response.ContentType);
    }

    private static DefaultHttpContext CreateContext(byte[] body)
    {
        var context = CreateWritableContext();
        context.Request.Body = new MemoryStream(body);
        context.Request.ContentLength = body.Length;
        context.Request.ContentType = "application/json";
        return context;
    }

    private static DefaultHttpContext CreateWritableContext()
    {
        var services = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();
        var context = new DefaultHttpContext
        {
            RequestServices = services
        };
        context.Response.Body = new MemoryStream();
        context.TraceIdentifier = "synthetic-trace-id";
        return context;
    }
}
