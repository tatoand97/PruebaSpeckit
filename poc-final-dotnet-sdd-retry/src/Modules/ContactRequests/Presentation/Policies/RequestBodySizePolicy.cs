using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Policies;

public static class RequestBodySizePolicy
{
    public const int MaximumBytes = 8192;

    public static async Task<byte[]> ReadBodyAsync(
        HttpRequest request,
        CancellationToken cancellationToken)
    {
        if (request.ContentLength > MaximumBytes)
        {
            throw new RequestBodyTooLargeException();
        }

        using var body = new MemoryStream();
        var buffer = new byte[4096];

        while (true)
        {
            var read = await request.Body.ReadAsync(buffer, cancellationToken);
            if (read == 0)
            {
                break;
            }

            if (body.Length + read > MaximumBytes)
            {
                throw new RequestBodyTooLargeException();
            }

            await body.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
        }

        return body.ToArray();
    }
}
