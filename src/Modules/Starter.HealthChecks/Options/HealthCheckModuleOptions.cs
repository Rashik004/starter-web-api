namespace Starter.HealthChecks.Options;

public sealed class HealthCheckModuleOptions
{
    public const string SectionName = "HealthChecks";

    /// <summary>
    /// URI for the sample external dependency health check.
    /// Empty string = check is registered but reports Degraded with "No URI configured" message.
    /// </summary>
    public string ExternalServiceUri { get; set; } = "";

    /// <summary>
    /// HTTP timeout in seconds for the external service probe.
    /// </summary>
    public int TimeoutSeconds { get; set; } = 5;
}
