namespace Starter.Caching.Options;

/// <summary>
/// Configuration options for the caching module, bound to the "Caching" section.
/// </summary>
public sealed class CachingOptions
{
    public const string SectionName = "Caching";

    /// <summary>Default absolute expiration in seconds (5 minutes).</summary>
    public int DefaultExpirationSeconds { get; set; } = 300;

    /// <summary>Sliding expiration in seconds (1 minute).</summary>
    public int SlidingExpirationSeconds { get; set; } = 60;

    /// <summary>
    /// Redis connection string. When null or empty, an in-memory distributed cache is used.
    /// </summary>
    public string? RedisConnectionString { get; set; }

    /// <summary>Redis key prefix used when Redis is enabled.</summary>
    public string RedisInstanceName { get; set; } = "starter:";
}
