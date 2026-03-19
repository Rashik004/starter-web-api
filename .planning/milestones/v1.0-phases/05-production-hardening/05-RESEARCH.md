# Phase 5: Production Hardening - Research

**Researched:** 2026-03-19
**Domain:** ASP.NET Core production middleware (rate limiting, caching, compression, response envelope, health checks)
**Confidence:** HIGH

## Summary

Phase 5 adds five independently removable production-hardening modules to the existing modular .NET 10 Web API starter. Each module follows the established `AddStarter{Module}`/`UseStarter{Module}` pattern on `IServiceCollection`/`WebApplication`, with strongly-typed `IOptions<T>` configuration backed by `appsettings.json`.

All five features (rate limiting, caching, response compression, response envelope, health checks) use built-in ASP.NET Core middleware or standard library patterns -- no third-party packages are required except for the EF Core database health check (`Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore`) which is an official Microsoft package. The response envelope is implemented via an opt-in `IResultFilter` attribute, preserving module removability since removing the filter has zero impact on endpoints that do not use it.

**Primary recommendation:** Build five separate class library projects (`Starter.RateLimiting`, `Starter.Caching`, `Starter.Compression`, `Starter.Responses`, `Starter.HealthChecks`), each owning its own config section, extension methods, and options class. Wire them into Program.cs in grouped sections. The response envelope filter lives in `Starter.Responses` and is opt-in per controller/action via `[ServiceFilter]` or a custom attribute -- never registered globally.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RATE-01 | Built-in System.Threading.RateLimiting / Microsoft.AspNetCore.RateLimiting middleware is used | Built into ASP.NET Core shared framework; `AddRateLimiter` + `UseRateLimiter` -- no NuGet needed |
| RATE-02 | Fixed window, sliding window, and token bucket policies are provided as defaults | `AddFixedWindowLimiter`, `AddSlidingWindowLimiter`, `AddTokenBucketLimiter` all documented with config binding |
| RATE-03 | Policy configuration is driven by appsettings.json | Options pattern with `IOptions<T>` + `BindConfiguration` matches project convention |
| RATE-04 | Both global and per-endpoint rate limiting policies are demonstrated | `GlobalLimiter` for global; `[EnableRateLimiting("policy")]` attribute for per-endpoint |
| CACH-01 | IMemoryCache is registered with configurable expiration defaults | `AddMemoryCache()` built into framework; options class owns default durations |
| CACH-02 | A sample cache-aside pattern is demonstrated in a service layer | Decorator or direct IMemoryCache injection into a sample cached service |
| CACH-03 | IDistributedCache is available with in-memory default, swappable to Redis | `AddDistributedMemoryCache()` default; `AddStackExchangeRedisCache()` via config swap |
| COMP-01 | Gzip and Brotli response compression middleware is available | Built-in `AddResponseCompression` with Brotli + Gzip providers |
| COMP-02 | Module is opt-in, disabled by default | Extension method available but not called in Program.cs by default; one-line enable |
| COMP-03 | HTTPS compression security considerations documented | CRIME/BREACH risks documented; `EnableForHttps = false` by default |
| RESP-01 | Consistent response format across all endpoints | `ApiResponse<T>` envelope in Starter.Shared with data/success/errors/timestamp |
| RESP-02 | Shared error shape for validation errors, not-found, unauthorized, and unhandled exceptions | Envelope wraps ProblemDetails for error cases; GlobalExceptionHandler already handles typed exceptions |
| RESP-03 | Response envelope is opt-in via attribute or action filter (not global middleware) | `IResultFilter` applied via `[ServiceFilter]` or custom attribute on controllers/actions |
| HLTH-01 | /health endpoint returns aggregate health status | `MapHealthChecks("/health")` with no predicate = all checks |
| HLTH-02 | /health/ready endpoint returns readiness status | `MapHealthChecks("/health/ready")` with `Predicate = hc => hc.Tags.Contains("ready")` |
| HLTH-03 | /health/live endpoint returns liveness status | `MapHealthChecks("/health/live")` with `Predicate = _ => false` (always alive if process running) |
| HLTH-04 | Database connectivity health check is included | `AddDbContextCheck<AppDbContext>()` from Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore |
| HLTH-05 | A sample custom health check for external dependencies | Custom `IHealthCheck` implementation checking a configurable URI |
</phase_requirements>

## Standard Stack

### Core (Built-in -- no NuGet packages needed)

These capabilities are part of the `Microsoft.AspNetCore.App` shared framework already referenced by all module `.csproj` files:

| Feature | Namespace | Purpose | Why Standard |
|---------|-----------|---------|--------------|
| Rate Limiting | `Microsoft.AspNetCore.RateLimiting` / `System.Threading.RateLimiting` | Request rate limiting middleware | Built-in since .NET 7; official recommendation over third-party AspNetCoreRateLimit |
| Response Compression | `Microsoft.AspNetCore.ResponseCompression` | Gzip + Brotli compression middleware | Built-in; no package needed |
| Health Checks | `Microsoft.Extensions.Diagnostics.HealthChecks` | Health endpoint infrastructure | Built-in since .NET 2.1 |
| Memory Cache | `Microsoft.Extensions.Caching.Memory` | In-process IMemoryCache | Built-in |
| Distributed Cache | `Microsoft.Extensions.Caching.Distributed` | IDistributedCache abstraction | Built-in (in-memory default) |
| Action Filters | `Microsoft.AspNetCore.Mvc.Filters` | IResultFilter for response wrapping | Built-in MVC filter pipeline |

### Supporting (NuGet packages required)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore | 10.0.5 | `AddDbContextCheck<T>()` for database health | HLTH-04 database connectivity check |
| Microsoft.Extensions.Caching.StackExchangeRedis | 10.0.5 | `AddStackExchangeRedisCache()` for Redis IDistributedCache | CACH-03 Redis swap (referenced but optional at runtime) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Built-in rate limiting | AspNetCoreRateLimit (third-party) | Third-party has more features but built-in is the .NET standard; no dependency needed |
| IMemoryCache + IDistributedCache | HybridCache (Microsoft.Extensions.Caching.Hybrid 10.4.0) | HybridCache is GA and excellent but adds complexity; requirements specify IMemoryCache + IDistributedCache explicitly |
| Custom IResultFilter envelope | Global middleware | Global middleware would break module removability; filter is opt-in per requirement RESP-03 |
| AddDbContextCheck | AspNetCore.HealthChecks.Sqlite + .SqlServer + .NpgSql | Provider-specific checks add 3 packages; AddDbContextCheck works with any EF Core provider automatically |

**Installation (in respective module .csproj files):**
```bash
# Starter.HealthChecks project
dotnet add src/Starter.HealthChecks/Starter.HealthChecks.csproj package Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore --version 10.0.5

# Starter.Caching project (Redis reference -- optional runtime dependency)
dotnet add src/Starter.Caching/Starter.Caching.csproj package Microsoft.Extensions.Caching.StackExchangeRedis --version 10.0.5
```

**Version verification:** Versions confirmed via `dotnet package search` against nuget.org on 2026-03-19. EF Core packages already in project at 10.0.5.

## Architecture Patterns

### Recommended Project Structure
```
src/
  Starter.RateLimiting/
    Options/RateLimitingOptions.cs        # Strongly-typed config
    RateLimitingExtensions.cs             # AddAppRateLimiting / UseAppRateLimiting
    Starter.RateLimiting.csproj           # FrameworkReference only
  Starter.Caching/
    Options/CachingOptions.cs             # Expiration defaults, Redis connection string
    CachingExtensions.cs                  # AddAppCaching (IMemoryCache + IDistributedCache)
    Starter.Caching.csproj               # + StackExchangeRedis package ref
  Starter.Compression/
    Options/CompressionOptions.cs         # EnableForHttps, compression levels
    CompressionExtensions.cs              # AddAppCompression / UseAppCompression
    Starter.Compression.csproj            # FrameworkReference only
  Starter.Responses/
    Filters/ApiResponseFilter.cs          # IResultFilter wrapping OkObjectResult etc.
    Attributes/WrapResponseAttribute.cs   # Marker attribute or ServiceFilter shortcut
    ResponsesExtensions.cs               # AddAppResponses (registers filter in DI)
    Starter.Responses.csproj             # References Starter.Shared for envelope type
  Starter.HealthChecks/
    Checks/ExternalServiceHealthCheck.cs  # Sample custom IHealthCheck
    Options/HealthCheckOptions.cs         # External dependency URI config
    HealthChecksExtensions.cs            # AddAppHealthChecks / UseAppHealthChecks
    Starter.HealthChecks.csproj          # + EF Core HealthChecks package
  Starter.Shared/
    Responses/ApiResponse.cs             # Envelope type (public, used by Responses module)
```

### Pattern 1: Rate Limiting Module

**What:** Configures three named rate limiting policies (fixed window, sliding window, token bucket) and a global limiter, all driven by `appsettings.json`.

**When to use:** All API endpoints should have rate limiting in production.

**Example:**
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit
// RateLimitingOptions.cs
public sealed class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";

    public bool Enabled { get; set; } = true;
    public int GlobalPermitLimit { get; set; } = 100;
    public int GlobalWindowSeconds { get; set; } = 60;
    public FixedWindowPolicy FixedWindow { get; set; } = new();
    public SlidingWindowPolicy SlidingWindow { get; set; } = new();
    public TokenBucketPolicy TokenBucket { get; set; } = new();
}

public sealed class FixedWindowPolicy
{
    public int PermitLimit { get; set; } = 10;
    public int WindowSeconds { get; set; } = 10;
    public int QueueLimit { get; set; } = 0;
}

public sealed class SlidingWindowPolicy
{
    public int PermitLimit { get; set; } = 30;
    public int WindowSeconds { get; set; } = 30;
    public int SegmentsPerWindow { get; set; } = 3;
    public int QueueLimit { get; set; } = 0;
}

public sealed class TokenBucketPolicy
{
    public int TokenLimit { get; set; } = 50;
    public int ReplenishmentPeriodSeconds { get; set; } = 10;
    public int TokensPerPeriod { get; set; } = 10;
    public int QueueLimit { get; set; } = 0;
}

// RateLimitingExtensions.cs
public static IServiceCollection AddAppRateLimiting(this IServiceCollection services,
    IConfiguration configuration)
{
    services.AddOptions<RateLimitingOptions>()
        .BindConfiguration(RateLimitingOptions.SectionName)
        .ValidateDataAnnotations()
        .ValidateOnStart();

    var options = configuration.GetSection(RateLimitingOptions.SectionName)
        .Get<RateLimitingOptions>() ?? new();

    services.AddRateLimiter(limiterOptions =>
    {
        limiterOptions.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

        // Global limiter partitioned by IP
        limiterOptions.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(
            httpContext => RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = options.GlobalPermitLimit,
                    Window = TimeSpan.FromSeconds(options.GlobalWindowSeconds),
                    AutoReplenishment = true
                }));

        // Named policies
        limiterOptions.AddFixedWindowLimiter("fixed", opt => { /* bind from options */ });
        limiterOptions.AddSlidingWindowLimiter("sliding", opt => { /* bind from options */ });
        limiterOptions.AddTokenBucketLimiter("token", opt => { /* bind from options */ });
    });

    return services;
}

public static WebApplication UseAppRateLimiting(this WebApplication app)
{
    app.UseRateLimiter();
    return app;
}
```

### Pattern 2: Health Checks with Liveness/Readiness/Aggregate

**What:** Three health check endpoints with tagged health checks for filtering.

**When to use:** Every production API needs health checks for orchestrators (Kubernetes, Azure App Service, etc.).

**Example:**
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks
// HealthChecksExtensions.cs
public static WebApplicationBuilder AddAppHealthChecks(this WebApplicationBuilder builder)
{
    builder.Services.AddOptions<HealthCheckModuleOptions>()
        .BindConfiguration(HealthCheckModuleOptions.SectionName)
        .ValidateDataAnnotations()
        .ValidateOnStart();

    builder.Services.AddHealthChecks()
        .AddDbContextCheck<AppDbContext>(
            name: "database",
            tags: new[] { "ready" })
        .AddCheck<ExternalServiceHealthCheck>(
            name: "external-service",
            tags: new[] { "ready" });

    return builder;
}

public static WebApplication UseAppHealthChecks(this WebApplication app)
{
    // Aggregate: runs ALL checks
    app.MapHealthChecks("/health", new() { ResponseWriter = WriteResponse });

    // Readiness: only checks tagged "ready"
    app.MapHealthChecks("/health/ready", new()
    {
        Predicate = check => check.Tags.Contains("ready"),
        ResponseWriter = WriteResponse
    });

    // Liveness: no checks -- if the process is running, it's alive
    app.MapHealthChecks("/health/live", new()
    {
        Predicate = _ => false,
        ResponseWriter = WriteResponse
    });

    return app;
}
```

### Pattern 3: Response Envelope via Opt-In Action Filter

**What:** An `IResultFilter` that wraps successful responses in a standardized `ApiResponse<T>` envelope. Applied via attribute, not globally.

**When to use:** Controllers/actions that want consistent response wrapping apply the attribute; others remain untouched.

**Example:**
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters
// ApiResponse<T> in Starter.Shared
public sealed class ApiResponse<T>
{
    public bool Success { get; init; }
    public T? Data { get; init; }
    public string? Error { get; init; }
    public IDictionary<string, string[]>? Errors { get; init; }
    public DateTime Timestamp { get; init; } = DateTime.UtcNow;
}

// ApiResponseFilter.cs in Starter.Responses
internal sealed class ApiResponseFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        if (context.Result is ObjectResult objectResult
            && objectResult.Value is not ApiResponse<object>
            && objectResult.StatusCode is >= 200 and < 300)
        {
            context.Result = new ObjectResult(new ApiResponse<object>
            {
                Success = true,
                Data = objectResult.Value,
                Timestamp = DateTime.UtcNow
            })
            {
                StatusCode = objectResult.StatusCode
            };
        }
    }

    public void OnResultExecuted(ResultExecutedContext context) { }
}

// Usage on a controller:
[ServiceFilter(typeof(ApiResponseFilter))]
[ApiVersion(1.0)]
[ApiController]
[Route("api/v{version:apiVersion}/todos")]
public class TodoController : ControllerBase { }
```

### Pattern 4: Cache-Aside in Service Layer

**What:** Service wraps data access with IMemoryCache check-then-fetch pattern.

**When to use:** Read-heavy endpoints where data does not change frequently.

**Example:**
```csharp
// A sample cached service demonstrating the cache-aside pattern
internal sealed class CachedTodoService : ITodoService
{
    private readonly ITodoService _inner;
    private readonly IMemoryCache _cache;
    private readonly CachingOptions _options;

    public async Task<IReadOnlyList<TodoItemDto>> GetAllAsync(CancellationToken ct)
    {
        var key = "todos:all";
        if (_cache.TryGetValue(key, out IReadOnlyList<TodoItemDto>? cached) && cached is not null)
            return cached;

        var items = await _inner.GetAllAsync(ct);
        _cache.Set(key, items, TimeSpan.FromSeconds(_options.DefaultExpirationSeconds));
        return items;
    }
}
```

### Pattern 5: Response Compression (Opt-In, Disabled by Default)

**What:** Gzip + Brotli compression middleware available via extension method but NOT called in default Program.cs.

**When to use:** Enable when app is directly exposed to clients (not behind a reverse proxy that handles compression).

**Example:**
```csharp
// CompressionExtensions.cs
public static IServiceCollection AddAppCompression(this IServiceCollection services,
    IConfiguration configuration)
{
    services.AddOptions<CompressionModuleOptions>()
        .BindConfiguration(CompressionModuleOptions.SectionName)
        .ValidateDataAnnotations()
        .ValidateOnStart();

    var options = configuration.GetSection(CompressionModuleOptions.SectionName)
        .Get<CompressionModuleOptions>() ?? new();

    services.AddResponseCompression(opts =>
    {
        opts.EnableForHttps = options.EnableForHttps; // false by default
        opts.Providers.Add<BrotliCompressionProvider>();
        opts.Providers.Add<GzipCompressionProvider>();
    });

    services.Configure<BrotliCompressionProviderOptions>(o =>
        o.Level = CompressionLevel.Fastest);
    services.Configure<GzipCompressionProviderOptions>(o =>
        o.Level = CompressionLevel.Fastest);

    return services;
}

public static WebApplication UseAppCompression(this WebApplication app)
{
    app.UseResponseCompression(); // Must be before any middleware that writes responses
    return app;
}
```

### Anti-Patterns to Avoid

- **Registering response envelope filter globally:** This would break module removability (RESP-03). The filter MUST be opt-in per controller/action, not added to `options.Filters`.
- **Calling UseAppCompression in default Program.cs:** Compression is opt-in (COMP-02). The extension method exists but the default Program.cs has it commented out or documented but not called.
- **Using third-party rate limiting libraries:** Requirements explicitly state built-in `System.Threading.RateLimiting` (RATE-01).
- **Hardcoding rate limit values:** All rate limit policies must bind from config (RATE-03).
- **Making health check endpoints require authorization:** Health endpoints (`/health/*`) should be anonymous for orchestrator probes.
- **Putting ApiResponse<T> in the Responses module:** The envelope type belongs in `Starter.Shared` so controllers can reference it without depending on the Responses module.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rate limiting | Custom middleware counting requests | `AddRateLimiter` + built-in policies | Thread-safe, partition-aware, handles queuing, 429 status |
| Database health check | Manual `DbContext.Database.CanConnect()` | `AddDbContextCheck<AppDbContext>()` | Handles timeout, tags, failure status automatically |
| Response compression | Custom Gzip stream wrappers | `AddResponseCompression` middleware | Handles Accept-Encoding negotiation, Vary headers, MIME types |
| Cache stampede protection | Double-checked locking in service | `IMemoryCache.GetOrCreate` / `SemaphoreSlim` | Built-in atomic get-or-add pattern handles concurrency |
| Health check JSON response | Manual JSON serialization per endpoint | Custom `ResponseWriter` delegate registered once | Reused across all three health endpoints |

**Key insight:** Every feature in this phase has a mature built-in ASP.NET Core implementation. The primary engineering challenge is not building these features but structuring them as independently removable modules with config-driven behavior.

## Common Pitfalls

### Pitfall 1: UseRateLimiter Placement
**What goes wrong:** Rate limiting does not apply to controllers or returns unexpected behavior.
**Why it happens:** `UseRateLimiter()` must be called AFTER `UseRouting()` (which is implicit in .NET 10) when using endpoint-specific rate limiting attributes like `[EnableRateLimiting]`.
**How to avoid:** Place `UseAppRateLimiting()` after `UseHttpsRedirection()` and before `UseAuthentication()` in the middleware pipeline.
**Warning signs:** Rate limit attributes are ignored; all requests bypass limits.

### Pitfall 2: Response Compression Over HTTPS
**What goes wrong:** Enabling compression over HTTPS exposes the app to CRIME/BREACH side-channel attacks.
**Why it happens:** Compressed ciphertext length reveals information about plaintext content.
**How to avoid:** Keep `EnableForHttps = false` (the default). Document that enabling it is a conscious security tradeoff. When enabled, use anti-forgery tokens to mitigate BREACH.
**Warning signs:** Compression is silently enabled for HTTPS without documentation.

### Pitfall 3: UseResponseCompression Middleware Order
**What goes wrong:** Compression does not work because middleware is placed after response-writing middleware.
**Why it happens:** `UseResponseCompression()` must be called BEFORE any middleware that writes response bodies (before `UseStaticFiles`, `MapControllers`, etc.).
**How to avoid:** Place `UseAppCompression()` very early in the pipeline -- right after exception handling.
**Warning signs:** Accept-Encoding header is sent but Content-Encoding is never returned.

### Pitfall 4: Global Response Envelope Breaking Module Removability
**What goes wrong:** Removing the Responses module causes compilation errors or runtime failures in all controllers.
**Why it happens:** If the envelope filter is registered globally, removing it causes errors. If controllers reference types from `Starter.Responses`, they have a hard dependency.
**How to avoid:** Put `ApiResponse<T>` in `Starter.Shared` (already referenced by all controllers). The filter itself is registered via `AddAppResponses()` in DI and applied via `[ServiceFilter]` attribute -- removing the module just means the attribute has no effect or is removed.
**Warning signs:** Controllers import namespaces from `Starter.Responses`.

### Pitfall 5: HealthChecks DbContext Requiring Separate Package
**What goes wrong:** `AddDbContextCheck<AppDbContext>()` does not compile.
**Why it happens:** The `AddDbContextCheck` extension lives in `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore`, which is NOT part of the shared framework -- it requires a NuGet package reference.
**How to avoid:** Add the package to `Starter.HealthChecks.csproj`. The `AppDbContext` type is internal in `Starter.Data`, so `Starter.HealthChecks` needs `InternalsVisibleTo` OR uses a different approach (see notes below).
**Warning signs:** Compilation error on `AddDbContextCheck<AppDbContext>`.

### Pitfall 6: InternalsVisibleTo for AppDbContext
**What goes wrong:** `Starter.HealthChecks` cannot reference `AppDbContext` because it is `internal` in `Starter.Data`.
**Why it happens:** The project convention is internal-by-default (FOUND-07).
**How to avoid:** Two approaches: (a) Add `InternalsVisibleTo Include="Starter.HealthChecks"` in `Starter.Data.csproj` (already done for migration assemblies and Auth.Identity), or (b) Register the health check from within `Starter.Data` itself as part of `AddAppData()`, but that couples data to health checks. Approach (a) is preferred -- it follows the existing pattern.
**Warning signs:** Trying to make `AppDbContext` public breaks the internal-visibility convention.

### Pitfall 7: Caching Module and Starter.Data Coupling
**What goes wrong:** The caching sample is tightly coupled to `TodoService` in `Starter.Data`, making it non-removable.
**Why it happens:** If the cached service is a decorator wrapping `TodoService`, it must live in or reference `Starter.Data`.
**How to avoid:** The caching module (`Starter.Caching`) registers `IMemoryCache` and `IDistributedCache` only. The cache-aside SAMPLE can be a separate cached service class registered conditionally, or demonstrated as a standalone sample endpoint in the Host project that uses `IMemoryCache` directly. The cleanest approach: `Starter.Caching` just registers the cache infrastructure, and a sample cached controller endpoint in the Host project demonstrates the pattern.
**Warning signs:** `Starter.Caching` has a ProjectReference to `Starter.Data`.

## Code Examples

Verified patterns from official sources:

### Rate Limiting with Config Binding
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.AddFixedWindowLimiter("fixed", opt =>
    {
        opt.PermitLimit = myOptions.PermitLimit;
        opt.Window = TimeSpan.FromSeconds(myOptions.Window);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = myOptions.QueueLimit;
    });

    options.AddSlidingWindowLimiter("sliding", opt =>
    {
        opt.PermitLimit = myOptions.SlidingPermitLimit;
        opt.Window = TimeSpan.FromSeconds(myOptions.Window);
        opt.SegmentsPerWindow = myOptions.SegmentsPerWindow;
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = myOptions.QueueLimit;
    });

    options.AddTokenBucketLimiter("token", opt =>
    {
        opt.TokenLimit = myOptions.TokenLimit;
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = myOptions.QueueLimit;
        opt.ReplenishmentPeriod = TimeSpan.FromSeconds(myOptions.ReplenishmentPeriod);
        opt.TokensPerPeriod = myOptions.TokensPerPeriod;
        opt.AutoReplenishment = true;
    });
});
```

### Per-Endpoint Rate Limiting via Attribute
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit
[EnableRateLimiting("fixed")]
public class SomeController : ControllerBase
{
    [DisableRateLimiting]
    public IActionResult NoLimit() => Ok();

    [EnableRateLimiting("sliding")]
    public IActionResult SlidingLimited() => Ok();
}
```

### Health Check JSON Response Writer
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks
private static Task WriteResponse(HttpContext context, HealthReport report)
{
    context.Response.ContentType = "application/json; charset=utf-8";
    var options = new JsonWriterOptions { Indented = true };
    using var memoryStream = new MemoryStream();
    using (var jsonWriter = new Utf8JsonWriter(memoryStream, options))
    {
        jsonWriter.WriteStartObject();
        jsonWriter.WriteString("status", report.Status.ToString());
        jsonWriter.WriteStartObject("results");
        foreach (var entry in report.Entries)
        {
            jsonWriter.WriteStartObject(entry.Key);
            jsonWriter.WriteString("status", entry.Value.Status.ToString());
            jsonWriter.WriteString("description", entry.Value.Description);
            jsonWriter.WriteEndObject();
        }
        jsonWriter.WriteEndObject();
        jsonWriter.WriteEndObject();
    }
    return context.Response.WriteAsync(
        Encoding.UTF8.GetString(memoryStream.ToArray()));
}
```

### Custom IHealthCheck for External Dependency
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks
internal sealed class ExternalServiceHealthCheck(
    IHttpClientFactory httpClientFactory,
    IOptions<HealthCheckModuleOptions> options) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var client = httpClientFactory.CreateClient();
            var response = await client.GetAsync(
                options.Value.ExternalServiceUri, cancellationToken);
            return response.IsSuccessStatusCode
                ? HealthCheckResult.Healthy("External service is reachable.")
                : HealthCheckResult.Degraded($"External service returned {response.StatusCode}.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("External service is unreachable.", ex);
        }
    }
}
```

### Response Compression Configuration
```csharp
// Source: https://learn.microsoft.com/en-us/aspnet/core/performance/response-compression
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = false; // Security: disabled by default
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
});

builder.Services.Configure<BrotliCompressionProviderOptions>(options =>
    options.Level = CompressionLevel.Fastest);
builder.Services.Configure<GzipCompressionProviderOptions>(options =>
    options.Level = CompressionLevel.Fastest);
```

### IDistributedCache with Redis Swap
```csharp
// Default: in-memory distributed cache (no Redis needed)
services.AddDistributedMemoryCache();

// Redis: swap by changing config and adding one line
// services.AddStackExchangeRedisCache(options =>
// {
//     options.Configuration = configuration.GetConnectionString("Redis");
//     options.InstanceName = "starter:";
// });
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AspNetCoreRateLimit (third-party) | Built-in `Microsoft.AspNetCore.RateLimiting` | .NET 7 (Nov 2022) | No third-party dependency for rate limiting |
| IMemoryCache + IDistributedCache manual | HybridCache | .NET 9 GA (Mar 2025) | Simplifies cache-aside to one line; but requirements specify IMemoryCache/IDistributedCache |
| StatusCodePages for errors | RFC 7807 ProblemDetails (already implemented) | .NET 7+ | Already in place via Phase 1 GlobalExceptionHandler |
| Manual health check middleware | Built-in `MapHealthChecks` | .NET 2.1+ | Mature, well-documented |
| IIS/Nginx compression | Built-in `ResponseCompression` middleware | .NET 1.0+ | For Kestrel-direct deployments |

**Deprecated/outdated:**
- `AspNetCoreRateLimit` package: Still works but built-in rate limiting is now the standard recommendation
- `AddHealthChecksUI`: Heavy UI package; not needed for API-only health endpoints

## Open Questions

1. **AppDbContext InternalsVisibleTo for HealthChecks**
   - What we know: AppDbContext is internal; health check module needs `AddDbContextCheck<AppDbContext>()`
   - What's unclear: Whether the planner prefers InternalsVisibleTo or registering the DB check within Starter.Data's extension
   - Recommendation: Use `InternalsVisibleTo` in Starter.Data.csproj (follows existing pattern used by migration assemblies and Auth.Identity)

2. **Cache-aside sample location**
   - What we know: Starter.Caching should register infrastructure (IMemoryCache, IDistributedCache); a sample demonstrates cache-aside
   - What's unclear: Whether the sample cached endpoint lives in the Host project or as a decorator in Starter.Data
   - Recommendation: Put a standalone `CacheDemoController` in the Host project that uses `IMemoryCache` directly. This avoids coupling Starter.Caching to Starter.Data. The sample shows the pattern; real users apply it to their own services.

3. **Response envelope and error responses**
   - What we know: RESP-02 requires shared error shape. GlobalExceptionHandler already returns ProblemDetails.
   - What's unclear: Whether errors should also be wrapped in `ApiResponse<T>` or remain as raw ProblemDetails
   - Recommendation: Success responses get `ApiResponse<T>` envelope via the opt-in filter. Error responses continue using ProblemDetails (from GlobalExceptionHandler) -- this is already a standardized format (RFC 7807). Document that the envelope is for success paths; ProblemDetails is for error paths.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected -- tests directory has .gitkeep only |
| Config file | None -- Phase 6 will create test infrastructure |
| Quick run command | N/A |
| Full suite command | N/A |

### Phase Requirements --> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RATE-01 | Rate limiting middleware returns 429 | integration | N/A (Phase 6) | No -- Wave 0 |
| RATE-02 | Three policy types configurable | integration | N/A (Phase 6) | No -- Wave 0 |
| RATE-03 | Config drives policies | integration | N/A (Phase 6) | No -- Wave 0 |
| RATE-04 | Global + per-endpoint demo | manual | Visual inspection of controller attributes | N/A |
| CACH-01 | IMemoryCache registered | integration | N/A (Phase 6) | No -- Wave 0 |
| CACH-02 | Cache-aside demo | manual | Run endpoint twice, observe timing | N/A |
| CACH-03 | IDistributedCache swappable | manual | Config change verification | N/A |
| COMP-01 | Gzip/Brotli available | integration | N/A (Phase 6) | No -- Wave 0 |
| COMP-02 | Opt-in, disabled by default | manual | Verify Program.cs does not call UseAppCompression | N/A |
| COMP-03 | HTTPS risks documented | manual | Review code comments/README | N/A |
| RESP-01 | Consistent envelope | integration | N/A (Phase 6) | No -- Wave 0 |
| RESP-02 | Shared error shape | integration | N/A (Phase 6) | No -- Wave 0 |
| RESP-03 | Opt-in, removable | smoke | Remove module, verify build | No -- Wave 0 |
| HLTH-01 | /health aggregate | integration | N/A (Phase 6) | No -- Wave 0 |
| HLTH-02 | /health/ready | integration | N/A (Phase 6) | No -- Wave 0 |
| HLTH-03 | /health/live | integration | N/A (Phase 6) | No -- Wave 0 |
| HLTH-04 | DB health check | integration | N/A (Phase 6) | No -- Wave 0 |
| HLTH-05 | Custom health check | integration | N/A (Phase 6) | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `dotnet build` (no test suite yet)
- **Per wave merge:** `dotnet build` + manual endpoint verification
- **Phase gate:** All endpoints manually verified; build succeeds

### Wave 0 Gaps
- No test infrastructure exists (Phase 6 scope)
- Validation for this phase is build success + manual HTTP verification
- All integration test coverage deferred to Phase 6 (TEST-01 through TEST-07)

## Program.cs Integration Pattern

Based on the existing Program.cs structure, Phase 5 modules integrate as follows:

```csharp
// --- Observability ---
builder.AddAppLogging();

// --- Security ---
builder.AddAppAuthShared();
builder.AddAppIdentity();
builder.AddAppJwt();
builder.AddAppGoogle();

// --- Data ---
builder.AddAppData();

// --- API ---
builder.AddAppCors();
builder.AddAppOpenApi();
builder.Services.AddAppVersioning();
builder.Services.AddAppValidation();
builder.Services.AddAppExceptionHandling();
builder.Services.AddAppResponses();         // NEW: registers ApiResponseFilter in DI
builder.Services.AddAppRateLimiting(builder.Configuration);  // NEW: rate limiting policies
builder.Services.AddAppCaching(builder.Configuration);       // NEW: IMemoryCache + IDistributedCache
// builder.Services.AddAppCompression(builder.Configuration); // NEW: available but commented out (opt-in)
builder.Services.AddControllers();

// --- Health ---
builder.AddAppHealthChecks();               // NEW: health check registrations

var app = builder.Build();

// --- Middleware Pipeline ---
app.UseAppExceptionHandling();
// app.UseAppCompression();                 // NEW: available but commented out (must be before response-writing)
app.UseHttpsRedirection();
app.UseAppRequestLogging();
app.UseAppData();

app.UseAppRateLimiting();                   // NEW: after routing (implicit), before auth
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.UseAppOpenApi();
app.MapControllers();
app.UseAppHealthChecks();                   // NEW: maps /health, /health/ready, /health/live

app.Run();
```

## Sources

### Primary (HIGH confidence)
- [Rate limiting middleware in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit?view=aspnetcore-10.0) -- complete API reference for AddRateLimiter, policies, EnableRateLimiting attribute
- [Health checks in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-10.0) -- MapHealthChecks, tags, readiness/liveness, AddDbContextCheck, custom IHealthCheck
- [Response compression in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/performance/response-compression?view=aspnetcore-10.0) -- Gzip/Brotli configuration, EnableForHttps, CRIME/BREACH documentation
- [Filters in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/mvc/controllers/filters?view=aspnetcore-10.0) -- IResultFilter, ServiceFilterAttribute, filter ordering
- NuGet package search (nuget.org, 2026-03-19) -- verified versions: Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore 10.0.5, Microsoft.Extensions.Caching.StackExchangeRedis 10.0.5

### Secondary (MEDIUM confidence)
- [HybridCache GA announcement](https://devblogs.microsoft.com/dotnet/hybrid-cache-is-now-ga/) -- confirmed HybridCache is GA but requirements explicitly specify IMemoryCache/IDistributedCache
- [Xabaril/AspNetCore.Diagnostics.HealthChecks](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks) -- third-party health check packages at v9.0.0; not needed since AddDbContextCheck covers the DB requirement

### Tertiary (LOW confidence)
- None -- all findings verified against official Microsoft documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all built-in ASP.NET Core features, verified against .NET 10 docs
- Architecture: HIGH -- follows established project patterns (5 modules, AddStarter/UseStarter, IOptions, internal-by-default)
- Pitfalls: HIGH -- documented from official sources and verified against existing project structure (InternalsVisibleTo pattern, middleware ordering)

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable -- built-in framework features, unlikely to change)
