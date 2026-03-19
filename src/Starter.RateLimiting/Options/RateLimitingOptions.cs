namespace Starter.RateLimiting.Options;

/// <summary>
/// Configuration options for the rate limiting module.
/// Bind from appsettings.json section "RateLimiting".
/// </summary>
public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    /// <summary>Whether rate limiting is enabled.</summary>
    public bool Enabled { get; set; } = true;

    /// <summary>Maximum requests per window for the global IP-partitioned limiter.</summary>
    public int GlobalPermitLimit { get; set; } = 100;

    /// <summary>Window duration in seconds for the global limiter.</summary>
    public int GlobalWindowSeconds { get; set; } = 60;

    /// <summary>Configuration for the "fixed" named policy.</summary>
    public FixedWindowPolicy FixedWindow { get; set; } = new();

    /// <summary>Configuration for the "sliding" named policy.</summary>
    public SlidingWindowPolicy SlidingWindow { get; set; } = new();

    /// <summary>Configuration for the "token" named policy.</summary>
    public TokenBucketPolicy TokenBucket { get; set; } = new();

    /// <summary>Fixed window rate limiting policy settings.</summary>
    public sealed class FixedWindowPolicy
    {
        public int PermitLimit { get; set; } = 10;
        public int WindowSeconds { get; set; } = 10;
        public int QueueLimit { get; set; } = 0;
    }

    /// <summary>Sliding window rate limiting policy settings.</summary>
    public sealed class SlidingWindowPolicy
    {
        public int PermitLimit { get; set; } = 30;
        public int WindowSeconds { get; set; } = 30;
        public int SegmentsPerWindow { get; set; } = 3;
        public int QueueLimit { get; set; } = 0;
    }

    /// <summary>Token bucket rate limiting policy settings.</summary>
    public sealed class TokenBucketPolicy
    {
        public int TokenLimit { get; set; } = 50;
        public int ReplenishmentPeriodSeconds { get; set; } = 10;
        public int TokensPerPeriod { get; set; } = 10;
        public int QueueLimit { get; set; } = 0;
    }
}
