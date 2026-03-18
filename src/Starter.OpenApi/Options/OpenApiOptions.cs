namespace Starter.OpenApi.Options;

public sealed class OpenApiOptions
{
    public const string SectionName = "OpenApi";

    /// <summary>
    /// Whether to enable the Scalar interactive API documentation UI.
    /// Config-driven (not environment check) so internal APIs can expose docs in staging/production.
    /// </summary>
    public bool EnableScalar { get; set; } = true;

    /// <summary>
    /// Title displayed in the OpenAPI document and Scalar UI.
    /// </summary>
    public string Title { get; set; } = "Starter API";

    /// <summary>
    /// Description for the OpenAPI document.
    /// </summary>
    public string Description { get; set; } = "A modular .NET 10 Web API starter";
}
