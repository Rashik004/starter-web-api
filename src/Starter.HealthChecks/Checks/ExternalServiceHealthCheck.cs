using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Starter.HealthChecks.Options;

namespace Starter.HealthChecks.Checks;

internal sealed class ExternalServiceHealthCheck(
    IHttpClientFactory httpClientFactory,
    IOptions<HealthCheckModuleOptions> options) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(options.Value.ExternalServiceUri))
        {
            return HealthCheckResult.Degraded(
                "External service URI not configured. Set HealthChecks:ExternalServiceUri in appsettings.json.");
        }

        using var client = httpClientFactory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(options.Value.TimeoutSeconds);

        try
        {
            var response = await client.GetAsync(options.Value.ExternalServiceUri, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                return HealthCheckResult.Healthy(
                    $"External service is reachable ({response.StatusCode}).");
            }

            return HealthCheckResult.Degraded(
                $"External service returned {(int)response.StatusCode} {response.StatusCode}.");
        }
        catch (TaskCanceledException)
        {
            return HealthCheckResult.Unhealthy("External service health check timed out.");
        }
        catch (HttpRequestException ex)
        {
            return HealthCheckResult.Unhealthy("External service is unreachable.", ex);
        }
    }
}
