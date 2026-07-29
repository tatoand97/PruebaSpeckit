using System.Text.Json;
using System.Text.Json.Serialization;
using ContactRequests.Presentation.Contracts;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;

namespace ContactRequests.Presentation.Policies;

public static class StrictJsonInputPolicy
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow
    };

    public static async Task<CreateContactRequestRequest> ReadCreateRequestAsync(
        HttpRequest request,
        CancellationToken cancellationToken)
    {
        var body = await RequestBodySizePolicy.ReadBodyAsync(request, cancellationToken);

        try
        {
            return JsonSerializer.Deserialize<CreateContactRequestRequest>(body, Options)
                ?? throw InvalidJson();
        }
        catch (JsonException exception) when (
            exception.Message.Contains("could not be mapped", StringComparison.OrdinalIgnoreCase)
            || exception.Message.Contains("unmapped", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnknownJsonPropertyException();
        }
        catch (JsonException)
        {
            throw InvalidJson();
        }
    }

    private static ValidationException InvalidJson() =>
        new(new[] { new ValidationFailure("$", "Request body must be valid JSON.") });
}
