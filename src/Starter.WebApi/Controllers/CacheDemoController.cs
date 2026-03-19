using Asp.Versioning;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Starter.Caching.Options;

namespace Starter.WebApi.Controllers;

/// <summary>
/// Demonstrates the cache-aside pattern using IMemoryCache.
/// Hit GET /api/cachedemo/time twice -- the second call returns the cached value.
/// Use DELETE to evict.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[ApiVersionNeutral]
[EnableRateLimiting("sliding")]
public class CacheDemoController(IMemoryCache cache, IOptions<CachingOptions> options) : ControllerBase
{
    private const string CacheKey = "cache-demo:server-time";

    /// <summary>
    /// Returns the current server time, cached on first call.
    /// </summary>
    [HttpGet("time")]
    public IActionResult GetTime()
    {
        if (cache.TryGetValue(CacheKey, out string? cachedTime) && cachedTime is not null)
        {
            return Ok(new { Time = cachedTime, Source = "cache" });
        }

        var currentTime = DateTime.UtcNow.ToString("O");
        var cacheEntryOptions = new MemoryCacheEntryOptions()
            .SetAbsoluteExpiration(TimeSpan.FromSeconds(options.Value.DefaultExpirationSeconds))
            .SetSlidingExpiration(TimeSpan.FromSeconds(options.Value.SlidingExpirationSeconds));

        cache.Set(CacheKey, currentTime, cacheEntryOptions);
        return Ok(new { Time = currentTime, Source = "generated" });
    }

    /// <summary>
    /// Evicts the cached server time entry.
    /// </summary>
    [HttpDelete("time")]
    public IActionResult EvictTime()
    {
        cache.Remove(CacheKey);
        return NoContent();
    }
}
