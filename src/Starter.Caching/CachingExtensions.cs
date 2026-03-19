using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Starter.Caching.Options;

namespace Starter.Caching;

public static class CachingExtensions
{
    /// <summary>
    /// Registers IMemoryCache and IDistributedCache. By default, uses in-memory distributed
    /// cache. Set Caching:RedisConnectionString in appsettings.json to switch to Redis.
    /// </summary>
    public static IServiceCollection AddAppCaching(
        this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CachingOptions>()
            .BindConfiguration(CachingOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var options = configuration.GetSection(CachingOptions.SectionName)
            .Get<CachingOptions>() ?? new();

        services.AddMemoryCache();

        if (!string.IsNullOrWhiteSpace(options.RedisConnectionString))
        {
            services.AddStackExchangeRedisCache(redis =>
            {
                redis.Configuration = options.RedisConnectionString;
                redis.InstanceName = options.RedisInstanceName;
            });
        }
        else
        {
            services.AddDistributedMemoryCache();
        }

        return services;
    }
}
