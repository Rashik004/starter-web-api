namespace Starter.Compression.Options;

/// <summary>
/// Configuration options for the response compression module.
/// Bind from appsettings.json section "Compression".
/// </summary>
public sealed class CompressionModuleOptions
{
    public const string SectionName = "Compression";

    /// <summary>
    /// Whether to enable response compression for HTTPS requests.
    /// Security: Keep false to prevent CRIME/BREACH side-channel attacks.
    /// Enable only if you understand the risks and use anti-forgery tokens.
    /// </summary>
    public bool EnableForHttps { get; set; } = false;

    /// <summary>
    /// Brotli compression level. Valid values: Optimal, Fastest, NoCompression, SmallestSize.
    /// </summary>
    public string BrotliLevel { get; set; } = "Fastest";

    /// <summary>
    /// Gzip compression level. Valid values: Optimal, Fastest, NoCompression, SmallestSize.
    /// </summary>
    public string GzipLevel { get; set; } = "Fastest";
}
