using ContactRequests.Application.Errors;
using ContactRequests.Presentation.ExceptionHandling;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Test.Presentation;

public sealed class ContactRequestExceptionHandlerTests
{
    [Fact]
    public async Task TryHandleAsync_ReturnsTrueAndSets400_ForValidationException()
    {
        var httpContext = new DefaultHttpContext();
        var handler = new ContactRequestExceptionHandler();
        var exception = new ContactRequestValidationException(new Dictionary<string, string[]>
        {
            ["email"] = ["invalid"]
        });

        var handled = await handler.TryHandleAsync(httpContext, exception, CancellationToken.None);

        Assert.True(handled);
        Assert.Equal(StatusCodes.Status400BadRequest, httpContext.Response.StatusCode);
    }
}
