using Azure.Identity;
using Microsoft.Extensions.Configuration;

namespace Common.Infrastructure.Configuration;

public static class AzureAppConfigurationExtensions
{
    public static IConfigurationBuilder AddConditionalAzureAppConfiguration(
        this ConfigurationManager configuration)
    {
        var endpointValue = configuration["AzureAppConfiguration:Endpoint"];

        if (Uri.TryCreate(endpointValue, UriKind.Absolute, out var endpoint)
            && endpoint.Scheme == Uri.UriSchemeHttps)
        {
            configuration.AddAzureAppConfiguration(options =>
                options.Connect(endpoint, new DefaultAzureCredential()));
        }

        return configuration;
    }
}
