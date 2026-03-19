using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Threading.RateLimiting;
using Starter.RateLimiting.Options;

namespace Starter.RateLimiting;

public static class RateLimitingExtensions
{
    /// <summary>
    /// Registers rate limiting services with three named policies (fixed, sliding, token)
    /// and a global IP-partitioned limiter. All settings are driven by the "RateLimiting"
    /// configuration section.
    /// </summary>
    public static IServiceCollection AddAppRateLimiting(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<RateLimitingOptions>()
            .BindConfiguration(RateLimitingOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var options = configuration
            .GetSection(RateLimitingOptions.SectionName)
            .Get<RateLimitingOptions>() ?? new();

        services.AddRateLimiter(limiterOptions =>
        {
            limiterOptions.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            // Global limiter partitioned by client IP address
            limiterOptions.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(
                httpContext => RateLimitPartition.GetFixedWindowLimiter(
                    partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    factory: _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = options.GlobalPermitLimit,
                        Window = TimeSpan.FromSeconds(options.GlobalWindowSeconds),
                        AutoReplenishment = true
                    }));

            // Named policy: fixed window
            limiterOptions.AddFixedWindowLimiter("fixed", opt =>
            {
                opt.PermitLimit = options.FixedWindow.PermitLimit;
                opt.Window = TimeSpan.FromSeconds(options.FixedWindow.WindowSeconds);
                opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
                opt.QueueLimit = options.FixedWindow.QueueLimit;
            });

            // Named policy: sliding window
            limiterOptions.AddSlidingWindowLimiter("sliding", opt =>
            {
                opt.PermitLimit = options.SlidingWindow.PermitLimit;
                opt.Window = TimeSpan.FromSeconds(options.SlidingWindow.WindowSeconds);
                opt.SegmentsPerWindow = options.SlidingWindow.SegmentsPerWindow;
                opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
                opt.QueueLimit = options.SlidingWindow.QueueLimit;
            });

            // Named policy: token bucket
            limiterOptions.AddTokenBucketLimiter("token", opt =>
            {
                opt.TokenLimit = options.TokenBucket.TokenLimit;
                opt.ReplenishmentPeriod = TimeSpan.FromSeconds(options.TokenBucket.ReplenishmentPeriodSeconds);
                opt.TokensPerPeriod = options.TokenBucket.TokensPerPeriod;
                opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
                opt.QueueLimit = options.TokenBucket.QueueLimit;
                opt.AutoReplenishment = true;
            });
        });

        return services;
    }

    /// <summary>
    /// Adds the rate limiting middleware to the request pipeline.
    /// </summary>
    public static WebApplication UseAppRateLimiting(this WebApplication app)
    {
        app.UseRateLimiter();
        return app;
    }
}
