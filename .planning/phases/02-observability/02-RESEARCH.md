# Phase 2: Observability - Research

**Researched:** 2026-03-18
**Domain:** Serilog structured logging with two-stage bootstrap, configurable sinks, request logging, and enrichment in ASP.NET Core (.NET 10)
**Confidence:** HIGH

## Summary

This phase adds structured logging via Serilog as a removable module (`Starter.Logging`) following the extension method composition pattern established in Phase 1. The core pattern is a two-stage bootstrap: a lightweight bootstrap logger captures startup/crash events before the host initializes, then transitions to a fully-configured pipeline driven by `appsettings.json`. Four sinks (Console, File, Seq, OpenTelemetry) are supported, each controlled by an explicit `Enabled: true/false` flag in configuration. Since `serilog-settings-configuration` does NOT natively support an `Enabled` flag on sinks (this is an open feature request, issue #457, opened July 2025), the module must implement custom programmatic registration that reads each sink's `Enabled` property from `IConfiguration` and conditionally wires the sink.

Request logging via `UseSerilogRequestLogging()` replaces the noisy per-middleware ASP.NET Core logs with a single summary event per request. Health check endpoints are excluded by a custom `GetLevel` function. Enrichment includes environment name, machine name, correlation ID (from `X-Correlation-Id` header with `HttpContext.TraceIdentifier` fallback), and optional per-request properties (client IP, user agent, content type).

**Primary recommendation:** Use `Serilog.AspNetCore` 10.0.0 with `builder.Services.AddSerilog()` for DI integration, implement custom sink registration logic for the `Enabled` flag pattern, and use `Serilog.Enrichers.ClientInfo` 2.9.0 for correlation ID and client IP enrichment.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Console sink is the only sink enabled by default out-of-the-box
- All sinks (Console, File, Seq, OpenTelemetry) have full config blocks in appsettings.json with JSON comments explaining how to enable each one
- Each sink section has an explicit `Enabled: true/false` flag (not presence-based) -- requires custom registration logic to check the flag
- OpenTelemetry sink supports both generic OTLP endpoint URL and Azure Application Insights connection string, with both options documented in appsettings.json comments
- Sink configuration follows LOG-06: entirely appsettings-driven, zero code changes to enable/disable
- Bootstrap logger verbosity is Information level and above (captures startup milestones, not just errors)
- A swap marker log entry is written at Information level when transitioning from bootstrap to full Serilog pipeline (e.g., "Switching from bootstrap to full Serilog pipeline")
- `Log.CloseAndFlush()` is wired to application lifetime shutdown to guarantee all buffered log entries are flushed
- Health check endpoints (/health, /health/ready, /health/live) are excluded from `UseSerilogRequestLogging()` to prevent probe noise
- Log level is dynamic by HTTP status code: 200-399 -> Information, 400-499 -> Warning, 500+ -> Error
- Extra properties enriched per request: client IP address, request/response content type, user agent string -- all configurable (can be toggled on/off)
- Custom message template: `HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000}ms` (or similar clean, scannable format)
- Built-in enrichers: Environment name + Machine name (enabled by default)
- Correlation ID: read from custom `X-Correlation-Id` header, fall back to `HttpContext.TraceIdentifier` -- aligns with existing `traceId` field in GlobalExceptionHandler's ProblemDetails
- Enricher configuration is appsettings-driven (Serilog:Enrich section) -- add/remove enrichers without code changes
- The correlation ID from `X-Correlation-Id` header should align with the `traceId` already set in GlobalExceptionHandler's ProblemDetails -- same value should appear in both log entries and error responses
- All extra request logging properties (client IP, content type, user agent) must be individually toggleable, not all-or-nothing
- The swap marker ("Switching from bootstrap to full Serilog pipeline") should be visible in the console during startup

### Claude's Discretion
- Bootstrap logger sink (console-only, console + emergency file, etc.)
- Application property enricher (include or skip)
- Exact config section structure and key naming within Serilog configuration
- Implementation of the "Enabled" flag checking for sinks
- Request property configurability mechanism (IOptions, Serilog config, etc.)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LOG-01 | Serilog is the logging pipeline with two-stage bootstrap pattern | Two-stage bootstrap via `CreateBootstrapLogger()` + `builder.Services.AddSerilog()` with `ReadFrom.Configuration()` -- verified pattern from Serilog.AspNetCore 10.0.0 |
| LOG-02 | Console sink is always on in Development | Console sink enabled by default in appsettings.json `Serilog:Sinks:Console:Enabled: true`; bootstrap logger also uses Console |
| LOG-03 | File sink is configurable via appsettings.json | `Serilog.Sinks.File` 7.0.0 with custom Enabled flag check; rolling file with path/size configuration |
| LOG-04 | Azure Application Insights sink available via Serilog.Sinks.OpenTelemetry | `Serilog.Sinks.OpenTelemetry` 4.2.0 supports both OTLP endpoint and Azure App Insights via HttpProtobuf protocol |
| LOG-05 | Seq sink is configurable for local structured log viewing | `Serilog.Sinks.Seq` 9.0.0 with serverUrl from config; custom Enabled flag check |
| LOG-06 | Sink configuration is entirely driven by appsettings.json -- no code changes to enable/disable sinks | Custom programmatic registration reads `Enabled` flag per sink from `IConfiguration`; `ReadFrom.Configuration()` handles MinimumLevel, Enrichers, Properties |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Serilog.AspNetCore | 10.0.0 | ASP.NET Core integration, request logging middleware, `AddSerilog()` DI registration | Tracks .NET major version. Provides `CreateBootstrapLogger()`, `AddSerilog()`, `UseSerilogRequestLogging()`. Industry standard. |
| Serilog | 4.3.1 | Core structured logging library | Foundation for all sinks and enrichers. Transitive dependency of Serilog.AspNetCore. |
| Serilog.Settings.Configuration | 10.0.0 | Read Serilog config from `IConfiguration` (appsettings.json) | `ReadFrom.Configuration()` enables appsettings-driven MinimumLevel, Enrichers, Properties. Tracks .NET major version. |

### Sinks
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Serilog.Sinks.Console | 6.1.1 | Console output with structured formatting | Always in Development. Enabled by default. |
| Serilog.Sinks.File | 7.0.0 | Rolling file output | Production file logging. Disabled by default, enable via config. |
| Serilog.Sinks.Seq | 9.0.0 | Seq structured log server | Local dev structured log viewer. Disabled by default. |
| Serilog.Sinks.OpenTelemetry | 4.2.0 | OTLP export (Azure App Insights, Jaeger, etc.) | Cloud deployments. Supports gRPC and HttpProtobuf. Disabled by default. |

### Enrichers
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Serilog.Enrichers.Environment | 3.0.1 | WithEnvironmentName, WithMachineName | Always. Default enrichers per user decision. |
| Serilog.Enrichers.ClientInfo | 2.9.0 | WithClientIp, WithCorrelationId, WithRequestHeader | Request-scoped enrichment. Correlation ID from X-Correlation-Id header. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Serilog.Enrichers.ClientInfo (for correlation ID) | Serilog.Enrichers.CorrelationId (ekmsystems) | ClientInfo bundles correlation ID + client IP + request headers in one package. Fewer dependencies. |
| Serilog.Enrichers.ClientInfo (for correlation ID) | Custom middleware with LogContext.PushProperty | More control but more code to maintain. ClientInfo already handles the X-Correlation-Id header with fallback. |
| Serilog.Sinks.OpenTelemetry | Serilog.Sinks.ApplicationInsights | ApplicationInsights depends on deprecated Application Insights SDK. OpenTelemetry is the Microsoft-endorsed forward path. |

**Installation (for Starter.Logging project):**
```bash
dotnet add package Serilog.AspNetCore --version 10.0.0
dotnet add package Serilog.Settings.Configuration --version 10.0.0
dotnet add package Serilog.Sinks.Console --version 6.1.1
dotnet add package Serilog.Sinks.File --version 7.0.0
dotnet add package Serilog.Sinks.Seq --version 9.0.0
dotnet add package Serilog.Sinks.OpenTelemetry --version 4.2.0
dotnet add package Serilog.Enrichers.Environment --version 3.0.1
dotnet add package Serilog.Enrichers.ClientInfo --version 2.9.0
```

**Version verification:** All versions confirmed against NuGet registry on 2026-03-18.

## Architecture Patterns

### Recommended Project Structure
```
src/
  Starter.Logging/
    Starter.Logging.csproj
    LoggingExtensions.cs              # AddAppLogging() + UseAppLogging() public entry points
    Configuration/
      SinkRegistrar.cs                # Custom sink registration with Enabled flag logic
      RequestLoggingConfiguration.cs  # GetLevel, EnrichDiagnosticContext, MessageTemplate
    Options/
      LoggingSinkOptions.cs           # IOptions<T> for sink Enabled flags and request property toggles
```

### Pattern 1: Two-Stage Bootstrap Logger
**What:** Create a lightweight bootstrap logger immediately at program start that writes to Console at Information level. After the host builds, replace it with the full pipeline via `AddSerilog()`. Write a swap marker log line at the transition.
**When to use:** Always. This is required by LOG-01.
**Example:**
```csharp
// Program.cs - BEFORE var builder = WebApplication.CreateBuilder(args);
using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Log.Information("Starting application");
    var builder = WebApplication.CreateBuilder(args);

    // --- Observability ---
    builder.AddAppLogging(); // Registers Serilog, logs swap marker

    // ... rest of builder config ...

    var app = builder.Build();

    app.UseAppExceptionHandling();
    app.UseHttpsRedirection();
    app.UseAppRequestLogging(); // UseSerilogRequestLogging with custom config

    app.MapControllers();
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
```
**Source:** [Serilog.AspNetCore README](https://github.com/serilog/serilog-aspnetcore), [Nicholas Blumhardt bootstrap blog](https://nblumhardt.com/2020/10/bootstrap-logger/)

### Pattern 2: Custom Sink Registration with Enabled Flags
**What:** Since `serilog-settings-configuration` does NOT support an `Enabled` flag on WriteTo entries (open issue #457), implement custom logic that reads each sink's `Enabled` boolean from `IConfiguration` and conditionally calls `WriteTo.{Sink}()` programmatically.
**When to use:** For all four sinks (Console, File, Seq, OpenTelemetry).
**Example:**
```csharp
// Source: Custom pattern (Enabled flag is NOT natively supported)
internal static class SinkRegistrar
{
    public static LoggerConfiguration ConfigureSinks(
        this LoggerConfiguration loggerConfig,
        IConfiguration configuration)
    {
        var sinksSection = configuration.GetSection("Serilog:Sinks");

        if (sinksSection.GetValue<bool>("Console:Enabled"))
        {
            loggerConfig.WriteTo.Console(
                outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}");
        }

        if (sinksSection.GetValue<bool>("File:Enabled"))
        {
            var filePath = sinksSection.GetValue<string>("File:Path") ?? "Logs/log-.txt";
            loggerConfig.WriteTo.File(
                path: filePath,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 31);
        }

        if (sinksSection.GetValue<bool>("Seq:Enabled"))
        {
            var serverUrl = sinksSection.GetValue<string>("Seq:ServerUrl") ?? "http://localhost:5341";
            loggerConfig.WriteTo.Seq(serverUrl);
        }

        if (sinksSection.GetValue<bool>("OpenTelemetry:Enabled"))
        {
            var endpoint = sinksSection.GetValue<string>("OpenTelemetry:Endpoint")
                ?? "http://localhost:4317";
            var protocol = sinksSection.GetValue<string>("OpenTelemetry:Protocol") ?? "Grpc";
            loggerConfig.WriteTo.OpenTelemetry(options =>
            {
                options.Endpoint = endpoint;
                options.Protocol = protocol == "HttpProtobuf"
                    ? OtlpProtocol.HttpProtobuf
                    : OtlpProtocol.Grpc;
            });
        }

        return loggerConfig;
    }
}
```

### Pattern 3: AddSerilog with Hybrid Configuration
**What:** Use `builder.Services.AddSerilog()` callback that combines `ReadFrom.Configuration()` for MinimumLevel/Enrichers/Properties with custom programmatic sink registration for the Enabled flag pattern.
**When to use:** Always. This is the core registration pattern.
**Example:**
```csharp
// In LoggingExtensions.cs
public static WebApplicationBuilder AddAppLogging(
    this WebApplicationBuilder builder)
{
    builder.Services.AddSerilog((services, loggerConfig) =>
    {
        loggerConfig
            .ReadFrom.Configuration(builder.Configuration) // MinimumLevel, Enrichers, Properties
            .ReadFrom.Services(services)                   // DI-aware enrichers
            .ConfigureSinks(builder.Configuration);        // Custom Enabled-flag sinks

        Log.Information("Switching from bootstrap to full Serilog pipeline");
    });

    return builder;
}
```
**Source:** [Serilog.AspNetCore README](https://github.com/serilog/serilog-aspnetcore)

### Pattern 4: Request Logging with Health Check Exclusion
**What:** Configure `UseSerilogRequestLogging()` with custom `GetLevel` function that excludes health check paths and maps HTTP status codes to log levels. Enrich per-request with configurable properties.
**When to use:** Always for the middleware pipeline.
**Example:**
```csharp
// Source: Andrew Lock blog adapted for project requirements
public static WebApplication UseAppRequestLogging(
    this WebApplication app)
{
    app.UseSerilogRequestLogging(options =>
    {
        options.MessageTemplate =
            "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000}ms";

        options.GetLevel = (httpContext, elapsed, ex) =>
        {
            if (ex is not null) return LogEventLevel.Error;

            // Exclude health check endpoints
            var path = httpContext.Request.Path.Value;
            if (path is not null && path.StartsWith("/health", StringComparison.OrdinalIgnoreCase))
                return LogEventLevel.Verbose; // Filtered out at typical minimum levels

            return httpContext.Response.StatusCode switch
            {
                >= 500 => LogEventLevel.Error,
                >= 400 => LogEventLevel.Warning,
                _ => LogEventLevel.Information
            };
        };

        options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
        {
            // These can be toggled via IOptions -- implementation reads flags
            diagnosticContext.Set("ClientIp",
                httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown");
            diagnosticContext.Set("UserAgent",
                httpContext.Request.Headers.UserAgent.ToString());
            diagnosticContext.Set("RequestContentType",
                httpContext.Request.ContentType ?? "none");
            diagnosticContext.Set("ResponseContentType",
                httpContext.Response.ContentType ?? "none");
        };
    });

    return app;
}
```
**Source:** [Andrew Lock - Excluding health checks from Serilog request logging](https://andrewlock.net/using-serilog-aspnetcore-in-asp-net-core-3-excluding-health-check-endpoints-from-serilog-request-logging/)

### Pattern 5: Correlation ID Alignment with ProblemDetails traceId
**What:** Use `Serilog.Enrichers.ClientInfo` `WithCorrelationId()` configured to read from `X-Correlation-Id` header. When no header is present, the enricher generates a value. The GlobalExceptionHandler already uses `HttpContext.TraceIdentifier` for its `traceId` ProblemDetails extension. To align these, use middleware or enrich `HttpContext.TraceIdentifier` with the correlation ID from the header.
**When to use:** Always. Required by user decision for correlation alignment.
**Example:**
```csharp
// Correlation ID enricher configured via appsettings.json:
// "Serilog": { "Enrich": [
//   { "Name": "WithCorrelationId", "Args": { "headerName": "X-Correlation-Id", "addValueIfHeaderAbsence": true } }
// ]}
//
// Alternatively, a small middleware to sync header -> TraceIdentifier:
internal sealed class CorrelationIdMiddleware
{
    private const string CorrelationIdHeader = "X-Correlation-Id";
    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(CorrelationIdHeader, out var correlationId)
            && !string.IsNullOrWhiteSpace(correlationId))
        {
            context.TraceIdentifier = correlationId!;
        }
        await _next(context);
    }
}
```

### Anti-Patterns to Avoid
- **Configuring sinks only via ReadFrom.Configuration():** The Enabled flag pattern is NOT supported natively. Using only `ReadFrom.Configuration()` for WriteTo means you cannot conditionally enable/disable sinks via a simple boolean flag without removing the entire sink block.
- **Duplicating Console sink in both bootstrap and full config without understanding:** The bootstrap logger is completely replaced. If Console should work in both stages, it must be explicitly configured in both `CreateBootstrapLogger()` and the `AddSerilog()` callback.
- **Putting `Log.Logger = ...` and `Log.CloseAndFlush()` inside the Logging module:** The bootstrap logger and try/catch/finally MUST live in `Program.cs` because they need to exist before any module is loaded and after everything shuts down. The module's `AddAppLogging()` configures the full pipeline replacement.
- **Using `builder.Host.UseSerilog()` instead of `builder.Services.AddSerilog()`:** The `IWebHostBuilder.UseSerilog()` overload was removed in Serilog.AspNetCore 8.0.0. Use the `IServiceCollection.AddSerilog()` pattern.
- **Placing UseSerilogRequestLogging before UseExceptionHandler:** Exception handler must be first. Serilog request logging should come after exception handling and HTTPS redirection.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Correlation ID extraction from headers | Custom middleware parsing X-Correlation-Id | `Serilog.Enrichers.ClientInfo` `WithCorrelationId(headerName: "X-Correlation-Id")` | Handles missing header fallback, thread-safe, tested |
| Client IP extraction | Custom `RemoteIpAddress` reading | `Serilog.Enrichers.ClientInfo` `WithClientIp()` | Handles IPv4/IPv6, proxy-aware (with ForwardedHeaders) |
| Structured console output formatting | Custom `ILogEventSink` | `Serilog.Sinks.Console` with `outputTemplate` | Handles themes, structured formatting, special characters |
| Rolling file management | Custom file rotation logic | `Serilog.Sinks.File` with `rollingInterval` + `retainedFileCountLimit` | Handles race conditions, cleanup, buffering |
| Request logging summary | Custom middleware counting elapsed time | `UseSerilogRequestLogging()` | Integrates with diagnostic context, handles timing, status codes |

**Key insight:** Serilog's ecosystem has purpose-built packages for every enrichment and sink concern in this phase. The only custom code needed is the `Enabled` flag sink registration and the correlation ID / TraceIdentifier alignment.

## Common Pitfalls

### Pitfall 1: Bootstrap Logger Not Replaced
**What goes wrong:** If `AddSerilog()` is never called (e.g., module removed but Program.cs still has the bootstrap logger), the bootstrap console-only logger runs for the entire application lifetime.
**Why it happens:** The bootstrap logger is intentionally lightweight and does not read appsettings.json.
**How to avoid:** This is actually acceptable behavior -- it means the app runs fine without the Logging module, just with basic console logging. This supports the removability requirement.
**Warning signs:** No "Switching from bootstrap to full Serilog pipeline" swap marker in logs.

### Pitfall 2: Serilog.Settings.Configuration Sink Merging
**What goes wrong:** Using `ReadFrom.Configuration()` for WriteTo in combination with programmatic WriteTo calls results in duplicate sinks.
**Why it happens:** `ReadFrom.Configuration()` adds sinks from the Serilog:WriteTo section. If you also programmatically call `WriteTo.Console()`, Console is registered twice.
**How to avoid:** Use `ReadFrom.Configuration()` ONLY for MinimumLevel, Enrichers, and Properties. ALL sinks are registered programmatically via the custom `ConfigureSinks()` method that checks the Enabled flag. The Serilog:WriteTo section in appsettings.json should NOT be used for sink registration.
**Warning signs:** Duplicate log lines appearing in console or files.

### Pitfall 3: Health Check Exclusion Requires Path Matching
**What goes wrong:** Health check endpoints are logged despite exclusion intent, because endpoint metadata (`ctx.GetEndpoint()`) may be null if `UseSerilogRequestLogging()` is placed before `UseRouting()`.
**Why it happens:** Endpoint routing metadata is only available after `UseRouting()` runs.
**How to avoid:** Either use path-based matching (`RequestPath.StartsWith("/health")`) which works regardless of middleware order, OR ensure `UseSerilogRequestLogging()` is placed after `UseRouting()`. In this project, path-based matching is recommended because our health check paths are well-known constants.
**Warning signs:** Health probe requests generating Information-level log entries.

### Pitfall 4: Correlation ID vs TraceIdentifier Mismatch
**What goes wrong:** The correlation ID in Serilog logs does not match the `traceId` in ProblemDetails error responses.
**Why it happens:** `Serilog.Enrichers.ClientInfo` `WithCorrelationId()` reads/generates its own value from the header, while `GlobalExceptionHandler` uses `HttpContext.TraceIdentifier` (which defaults to Kestrel's connection-based ID).
**How to avoid:** Add a small middleware early in the pipeline that copies the `X-Correlation-Id` header value into `HttpContext.TraceIdentifier`. This way both the Serilog enricher and the GlobalExceptionHandler use the same value.
**Warning signs:** Different IDs appearing in log `CorrelationId` property vs ProblemDetails `traceId`.

### Pitfall 5: Log.CloseAndFlush() Not Called on Crash
**What goes wrong:** Buffered sinks (File, Seq, OpenTelemetry) lose final log entries on crash.
**Why it happens:** `Log.CloseAndFlush()` must be in a `finally` block in Program.cs to execute on both normal shutdown and unhandled exceptions.
**How to avoid:** The try/catch/finally block in Program.cs is mandatory and lives outside the module.
**Warning signs:** Missing log entries around crash time.

## Code Examples

### Complete appsettings.json Serilog Configuration
```json
// Source: Custom design per user decisions
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.Hosting.Lifetime": "Information",
        "System": "Warning"
      }
    },
    "Enrich": [
      "FromLogContext",
      "WithEnvironmentName",
      "WithMachineName",
      {
        "Name": "WithCorrelationId",
        "Args": {
          "headerName": "X-Correlation-Id",
          "addValueIfHeaderAbsence": true
        }
      }
    ],
    "Properties": {
      "Application": "Starter.WebApi"
    },
    "Sinks": {
      "Console": {
        "Enabled": true,
        "OutputTemplate": "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}"
      },
      "File": {
        "Enabled": false,
        // "To enable file logging, set Enabled to true"
        "Path": "Logs/log-.txt",
        "RollingInterval": "Day",
        "RetainedFileCountLimit": 31,
        "FileSizeLimitBytes": 104857600
      },
      "Seq": {
        "Enabled": false,
        // "To enable Seq, set Enabled to true and install Seq (https://datalust.co/seq)"
        "ServerUrl": "http://localhost:5341"
      },
      "OpenTelemetry": {
        "Enabled": false,
        // "For generic OTLP: set Endpoint to your collector (e.g., http://localhost:4317)"
        // "For Azure App Insights: set Endpoint to https://<region>.in.applicationinsights.azure.com/"
        // "  and Protocol to HttpProtobuf"
        "Endpoint": "http://localhost:4317",
        "Protocol": "Grpc"
      }
    },
    "RequestLogging": {
      "EnableClientIp": true,
      "EnableUserAgent": true,
      "EnableContentType": true
    }
  }
}
```

### Extension Method Pattern (AddAppLogging)
```csharp
// Source: Follows ExceptionHandlingExtensions.cs pattern from Phase 1
public static class LoggingExtensions
{
    /// <summary>
    /// Registers Serilog as the logging provider with configurable sinks.
    /// Must be called on WebApplicationBuilder (not IServiceCollection)
    /// because Serilog needs access to the Configuration.
    /// </summary>
    public static WebApplicationBuilder AddAppLogging(
        this WebApplicationBuilder builder)
    {
        builder.Services.AddSerilog((services, loggerConfig) =>
        {
            loggerConfig
                .ReadFrom.Configuration(builder.Configuration)
                .ReadFrom.Services(services)
                .ConfigureSinks(builder.Configuration);

            Log.Information("Switching from bootstrap to full Serilog pipeline");
        });

        return builder;
    }

    /// <summary>
    /// Adds Serilog request logging middleware with health check exclusion
    /// and configurable per-request enrichment.
    /// </summary>
    public static WebApplication UseAppRequestLogging(
        this WebApplication app)
    {
        app.UseSerilogRequestLogging(options =>
        {
            options.MessageTemplate =
                "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000}ms";
            options.GetLevel = DetermineLogLevel;
            options.EnrichDiagnosticContext = EnrichFromRequest;
        });

        return app;
    }
}
```

### Program.cs Integration Points
```csharp
// Source: Existing Program.cs with Phase 2 additions
using Serilog;
using Starter.ExceptionHandling;
using Starter.Logging; // NEW: Phase 2

// Two-stage bootstrap (lives in Program.cs, NOT in module)
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Log.Information("Starting application");

    var builder = WebApplication.CreateBuilder(args);

    // --- Observability ---
    builder.AddAppLogging(); // NEW: Phase 2

    // --- Security ---
    // (Phase 4)

    // --- Data ---
    // (Phase 3)

    // --- API ---
    builder.Services.AddControllers();
    builder.Services.AddAppExceptionHandling();

    var app = builder.Build();

    // --- Middleware Pipeline ---
    app.UseAppExceptionHandling(); // Must be first
    app.UseHttpsRedirection();
    app.UseAppRequestLogging(); // NEW: Phase 2 -- after exception handler

    app.MapControllers();
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `builder.Host.UseSerilog()` | `builder.Services.AddSerilog()` | Serilog.AspNetCore 8.0.0 (2023) | `IWebHostBuilder.UseSerilog()` removed. Use IServiceCollection extension. |
| `Serilog.Sinks.ApplicationInsights` | `Serilog.Sinks.OpenTelemetry` | 2024-2025 (Azure Monitor migration) | Classic App Insights SDK deprecated. OTLP is the forward path. |
| `CreateLogger()` | `CreateBootstrapLogger()` | Serilog.AspNetCore 5.0.0 (2021) | Bootstrap logger can be reconfigured; standard logger cannot. |
| Global `Log.Logger` only | `AddSerilog()` with DI | Serilog.AspNetCore 6.0.0+ | DI-aware enrichers and sinks. `ReadFrom.Services()` enables constructor injection. |

**Deprecated/outdated:**
- `Serilog.Sinks.ApplicationInsights`: Depends on deprecated Application Insights SDK. Use `Serilog.Sinks.OpenTelemetry` for Azure Monitor.
- `FluentValidation.AspNetCore`-style auto-pipeline for Serilog: Not applicable, but worth noting that Serilog does not have deprecated auto-wiring.
- `IWebHostBuilder.UseSerilog()`: Removed in v8.0.0. Use `IServiceCollection.AddSerilog()`.

## Open Questions

1. **Correlation ID synchronization approach**
   - What we know: `Serilog.Enrichers.ClientInfo` `WithCorrelationId()` can read from `X-Correlation-Id` header. `GlobalExceptionHandler` uses `HttpContext.TraceIdentifier`.
   - What's unclear: Whether a small middleware to copy the header into `TraceIdentifier` is sufficient, or if we need to also set `Activity.Current?.SetTag()` for distributed tracing alignment.
   - Recommendation: Implement the middleware approach. It is simple, covers the ProblemDetails alignment, and is forward-compatible with future OpenTelemetry tracing (Phase v2).

2. **Bootstrap logger sink choice (Claude's Discretion)**
   - What we know: Console-only is simplest and aligns with the development workflow.
   - What's unclear: Whether an emergency file sink is worth the added complexity for capturing crashes that happen before appsettings.json loads.
   - Recommendation: Console-only for bootstrap. If the app crashes before config loads, the console output is usually captured by the hosting environment (Docker, systemd, IIS). An emergency file adds complexity for a rare edge case.

3. **Application property enricher (Claude's Discretion)**
   - What we know: The `Properties` section in Serilog config can set a static `Application` property on all log events.
   - Recommendation: Include it. It costs nothing and is valuable when aggregating logs from multiple services in Seq or OTLP collectors. Set it to the app name from configuration.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | xunit.v3 3.2.2 (not yet installed -- Phase 6) |
| Config file | none -- test projects not yet created |
| Quick run command | `dotnet test --filter "Category=Logging"` |
| Full suite command | `dotnet test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOG-01 | Bootstrap logger captures startup, full pipeline replaces it | integration | `dotnet test --filter "LOG01"` | Wave 0 |
| LOG-02 | Console sink enabled in Development appsettings | unit (config parsing) | `dotnet test --filter "LOG02"` | Wave 0 |
| LOG-03 | File sink configurable via appsettings Enabled flag | unit (config parsing) | `dotnet test --filter "LOG03"` | Wave 0 |
| LOG-04 | OpenTelemetry sink configurable via appsettings | unit (config parsing) | `dotnet test --filter "LOG04"` | Wave 0 |
| LOG-05 | Seq sink configurable via appsettings Enabled flag | unit (config parsing) | `dotnet test --filter "LOG05"` | Wave 0 |
| LOG-06 | Enabling/disabling any sink requires only appsettings change | integration | `dotnet test --filter "LOG06"` | Wave 0 |

### Sampling Rate
- **Per task commit:** `dotnet build` (verify compilation)
- **Per wave merge:** `dotnet build` (no test project yet)
- **Phase gate:** Manual verification of logging output; test infrastructure deferred to Phase 6

### Wave 0 Gaps
- [ ] Test projects do not yet exist (created in Phase 6)
- [ ] Manual verification of log output is primary validation strategy for this phase
- [ ] Smoke test: run the app, verify console structured log output appears
- [ ] Smoke test: enable File sink in appsettings, verify log file created
- [ ] Smoke test: remove `AddAppLogging()` + project reference, verify clean build (removability)

## Sources

### Primary (HIGH confidence)
- [Serilog.AspNetCore GitHub](https://github.com/serilog/serilog-aspnetcore) - Two-stage bootstrap, AddSerilog API, UseSerilogRequestLogging
- [Serilog.Settings.Configuration GitHub](https://github.com/serilog/serilog-settings-configuration) - JSON configuration format, Enrich/Properties/MinimumLevel
- [Serilog.Sinks.OpenTelemetry GitHub](https://github.com/serilog/serilog-sinks-opentelemetry) - OTLP endpoint, protocol options, Azure App Insights
- [Serilog.Enrichers.ClientInfo GitHub](https://github.com/serilog-contrib/serilog-enrichers-clientinfo) - WithCorrelationId, WithClientIp, WithRequestHeader
- [NuGet Registry](https://api.nuget.org) - All package versions verified 2026-03-18

### Secondary (MEDIUM confidence)
- [Nicholas Blumhardt - Bootstrap Logger](https://nblumhardt.com/2020/10/bootstrap-logger/) - Original bootstrap pattern blog post
- [Andrew Lock - Excluding health checks](https://andrewlock.net/using-serilog-aspnetcore-in-asp-net-core-3-excluding-health-check-endpoints-from-serilog-request-logging/) - GetLevel function pattern for health check exclusion
- [codewithmukesh - Serilog in .NET 10](https://codewithmukesh.com/blog/structured-logging-with-serilog-in-aspnet-core/) - Complete .NET 10 setup example
- [Serilog Issue #1424](https://github.com/serilog/serilog/issues/1424) - Enabled flag discussion, maintainer guidance

### Tertiary (LOW confidence)
- [Serilog.Settings.Configuration Issue #457](https://github.com/serilog/serilog-settings-configuration/issues/457) - Sink Enabled feature request (open, not implemented). Confirms custom code is needed.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages verified on NuGet, versions confirmed, Serilog.AspNetCore 10.0.0 tracks .NET 10
- Architecture: HIGH - Two-stage bootstrap is well-documented official pattern; custom Enabled flag pattern is custom but straightforward
- Pitfalls: HIGH - Sink merging, health check exclusion, correlation ID alignment are well-documented in community sources
- Enabled flag not natively supported: HIGH - Confirmed via open issue #457 on serilog-settings-configuration (July 2025, still open)

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (30 days -- Serilog ecosystem is stable)
