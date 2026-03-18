# Architecture Research

**Domain:** Modular .NET 10 Web API Starter Template
**Researched:** 2026-03-18
**Confidence:** HIGH

## System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Starter.WebApi (Host)                            │
│  Program.cs + appsettings.json + launchSettings.json                │
│  Composes all modules via extension methods                         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │   .Auth      │  │  .Logging    │  │  .Diagnostics            │   │
│  │  Identity    │  │  Serilog     │  │  HealthChecks            │   │
│  │  Google OAuth│  │  Sinks       │  │  ExceptionHandling       │   │
│  │  JWT Bearer  │  │              │  │  ProblemDetails          │   │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘   │
│         │                 │                        │                 │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌────────────┴─────────────┐   │
│  │  .Data       │  │  .Api        │  │  .Caching                │   │
│  │  EF Core     │  │  Versioning  │  │  IMemoryCache            │   │
│  │  DbContext   │  │  Swagger     │  │  IDistributedCache       │   │
│  │  Migrations  │  │  CORS        │  │                          │   │
│  │              │  │  RateLimiting│  │                          │   │
│  │              │  │  Compression │  │                          │   │
│  │              │  │  Validation  │  │                          │   │
│  │              │  │  Envelope    │  │                          │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────────┘   │
│         │                 │                                          │
├─────────┴─────────────────┴──────────────────────────────────────────┤
│                   Starter.WebApi.Shared                              │
│  IOptions<T> base, common models, response envelope, constants      │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Starter.WebApi** (Host) | Composition root. Calls extension methods, owns Program.cs and appsettings.json. Contains no business logic. | ASP.NET Core Web API project (.NET 10). References all module projects. |
| **Starter.WebApi.Shared** | Shared abstractions, response envelope model, common constants, base option classes. | Class library. Referenced by all modules that need shared types. No NuGet dependencies beyond `Microsoft.Extensions.Options`. |
| **Starter.WebApi.Auth** | Identity store, Google OAuth, JWT Bearer token issuance/validation. Each sub-concern independently removable. | Class library. References `Microsoft.AspNetCore.Identity.EntityFrameworkCore`, `Microsoft.AspNetCore.Authentication.JwtBearer`, `Microsoft.AspNetCore.Authentication.Google`. |
| **Starter.WebApi.Logging** | Structured logging pipeline with configurable sinks (Console, File, App Insights, Seq). | Class library. References `Serilog.AspNetCore` plus sink packages. |
| **Starter.WebApi.Diagnostics** | Health checks, global exception handling middleware, ProblemDetails factory. | Class library. References `Microsoft.Extensions.Diagnostics.HealthChecks`, `AspNetCore.HealthChecks.UI.Client` (optional). |
| **Starter.WebApi.Data** | EF Core DbContext, entity configurations, migration helpers, database provider switching. | Class library. References `Microsoft.EntityFrameworkCore`, `Microsoft.EntityFrameworkCore.Sqlite`, provider packages. |
| **Starter.WebApi.Api** | API versioning, Swagger/OpenAPI, CORS, rate limiting, response compression, FluentValidation, response envelope action filter. | Class library. References `Asp.Versioning.Mvc.ApiExplorer`, `Swashbuckle.AspNetCore` or built-in OpenAPI, `FluentValidation.AspNetCore`. |
| **Starter.WebApi.Caching** | In-memory and distributed cache setup with IOptions-driven configuration. | Class library. References `Microsoft.Extensions.Caching.Memory`, optionally `Microsoft.Extensions.Caching.StackExchangeRedis`. |

## Recommended Project Structure

```
Starter.WebApi.slnx
│
├── src/
│   ├── Starter.WebApi/                          # Host (composition root)
│   │   ├── Controllers/                         # Sample v1/v2 controllers
│   │   │   ├── V1/
│   │   │   │   └── WeatherForecastController.cs
│   │   │   └── V2/
│   │   │       └── WeatherForecastController.cs
│   │   ├── Properties/
│   │   │   └── launchSettings.json
│   │   ├── Program.cs                           # Composition root (extension method calls)
│   │   ├── appsettings.json                     # All module config sections
│   │   ├── appsettings.Development.json
│   │   ├── appsettings.Production.json
│   │   └── Starter.WebApi.csproj
│   │
│   ├── Starter.WebApi.Shared/                   # Shared abstractions
│   │   ├── Models/
│   │   │   └── ApiResponse.cs                   # Response envelope
│   │   ├── Constants/
│   │   │   └── ConfigSections.cs                # Config section name constants
│   │   └── Starter.WebApi.Shared.csproj
│   │
│   ├── Starter.WebApi.Auth/                     # Authentication/Authorization
│   │   ├── Options/
│   │   │   ├── JwtOptions.cs
│   │   │   ├── GoogleAuthOptions.cs
│   │   │   └── IdentityOptions.cs
│   │   ├── Services/
│   │   │   └── TokenService.cs
│   │   ├── Data/
│   │   │   └── AuthDbContext.cs                 # Or extend main DbContext
│   │   ├── Extensions/
│   │   │   └── AuthServiceExtensions.cs         # AddStarterAuth(this IServiceCollection)
│   │   └── Starter.WebApi.Auth.csproj
│   │
│   ├── Starter.WebApi.Logging/                  # Structured logging
│   │   ├── Options/
│   │   │   └── LoggingOptions.cs
│   │   ├── Extensions/
│   │   │   └── LoggingServiceExtensions.cs      # AddStarterLogging(this WebApplicationBuilder)
│   │   └── Starter.WebApi.Logging.csproj
│   │
│   ├── Starter.WebApi.Diagnostics/              # Health, exceptions, ProblemDetails
│   │   ├── Middleware/
│   │   │   └── GlobalExceptionMiddleware.cs
│   │   ├── Options/
│   │   │   └── DiagnosticsOptions.cs
│   │   ├── Extensions/
│   │   │   └── DiagnosticsServiceExtensions.cs  # AddStarterDiagnostics(this IServiceCollection)
│   │   └── Starter.WebApi.Diagnostics.csproj
│   │
│   ├── Starter.WebApi.Data/                     # EF Core, migrations
│   │   ├── Contexts/
│   │   │   └── AppDbContext.cs
│   │   ├── Configurations/
│   │   │   └── SampleEntityConfiguration.cs
│   │   ├── Options/
│   │   │   └── DatabaseOptions.cs
│   │   ├── Extensions/
│   │   │   └── DataServiceExtensions.cs         # AddStarterData(this IServiceCollection)
│   │   ├── Migrations/
│   │   └── Starter.WebApi.Data.csproj
│   │
│   ├── Starter.WebApi.Api/                      # API infrastructure
│   │   ├── Filters/
│   │   │   └── ApiResponseWrapperFilter.cs
│   │   ├── Validation/
│   │   │   └── SampleValidator.cs
│   │   ├── Options/
│   │   │   ├── CorsOptions.cs
│   │   │   ├── RateLimitOptions.cs
│   │   │   └── SwaggerOptions.cs
│   │   ├── Extensions/
│   │   │   └── ApiServiceExtensions.cs          # AddStarterApi(this IServiceCollection)
│   │   └── Starter.WebApi.Api.csproj
│   │
│   └── Starter.WebApi.Caching/                  # Cache infrastructure
│       ├── Options/
│       │   └── CacheOptions.cs
│       ├── Extensions/
│       │   └── CachingServiceExtensions.cs      # AddStarterCaching(this IServiceCollection)
│       └── Starter.WebApi.Caching.csproj
│
├── tests/
│   ├── Starter.WebApi.Tests.Unit/               # Unit tests (service layer)
│   │   ├── Services/
│   │   └── Starter.WebApi.Tests.Unit.csproj
│   │
│   └── Starter.WebApi.Tests.Integration/        # Integration tests (WebApplicationFactory)
│       ├── Fixtures/
│       │   └── WebApiFixture.cs
│       ├── Controllers/
│       └── Starter.WebApi.Tests.Integration.csproj
│
└── scripts/
    └── add-migration.ps1                        # EF Core migration helper
```

### Structure Rationale

- **src/ and tests/ separation:** Standard .NET convention. Keeps production code and test code in distinct top-level folders. Solution filters can target either.
- **One Extensions/ folder per module:** Every module exposes its DI registration through a single static class in `Extensions/`. This is the module's public surface area for the host.
- **Options/ folder per module:** Each module owns its strongly-typed configuration class. The host's `appsettings.json` contains all sections; each module only reads its own section.
- **Shared project is minimal:** Only contains types that multiple modules reference (response envelope, config section name constants). Deliberately thin to avoid becoming a dumping ground.
- **Controllers in Host, not in modules:** Controllers stay in the host project because they orchestrate module services. Modules provide services and middleware, not endpoints. This keeps the routing surface in one place.

## Architectural Patterns

### Pattern 1: Extension Method Composition (Primary Pattern)

**What:** Each class library module exposes one or two static extension methods on `IServiceCollection` (for service registration) and optionally on `IApplicationBuilder`/`WebApplication` (for middleware/pipeline configuration). The host's `Program.cs` calls these in a clear, grouped order.

**When to use:** Always. This is the fundamental composition pattern for the entire solution.

**Trade-offs:**
- Pro: Each line in Program.cs is independently removable. Remove the call + project reference = feature removed.
- Pro: Program.cs remains scannable at a glance.
- Con: Extension methods can hide complexity. Naming must be clear.
- Con: Middleware ordering across modules requires the host to know the correct order.

**Example:**

```csharp
// Program.cs - Composition Root
var builder = WebApplication.CreateBuilder(args);

// ── Observability ──────────────────────────────────────
builder.AddStarterLogging();                    // Serilog pipeline

// ── Security ───────────────────────────────────────────
builder.Services.AddStarterAuth(builder.Configuration);  // Identity + Google + JWT

// ── Data ───────────────────────────────────────────────
builder.Services.AddStarterData(builder.Configuration);  // EF Core + SQLite
builder.Services.AddStarterCaching(builder.Configuration); // Memory/Distributed cache

// ── API ────────────────────────────────────────────────
builder.Services.AddStarterApi(builder.Configuration);   // Versioning, Swagger, CORS, Validation
builder.Services.AddStarterDiagnostics();                // Health checks, ProblemDetails

var app = builder.Build();

// ── Middleware Pipeline (order matters) ────────────────
app.UseStarterDiagnostics();     // ExceptionHandler, ProblemDetails (must be first)
app.UseHttpsRedirection();
app.UseStarterLogging();         // Request logging (Serilog request pipeline)
app.UseRouting();
app.UseStarterRateLimiting();    // Rate limiter (after routing, before auth)
app.UseCors();                   // CORS
app.UseAuthentication();         // Auth (after routing)
app.UseAuthorization();          // Authz (after authn)
app.UseStarterCompression();     // Response compression

// ── Endpoints ──────────────────────────────────────────
app.MapControllers();
app.MapStarterHealthChecks();    // /health, /health/ready, /health/live

app.Run();
```

### Pattern 2: IOptions<T> per Module with BindConfiguration

**What:** Each module defines a strongly-typed options class (e.g., `JwtOptions`, `DatabaseOptions`). The module's extension method binds it to a configuration section path using `BindConfiguration()`. The host's `appsettings.json` contains all sections.

**When to use:** Every module that has configurable behavior.

**Trade-offs:**
- Pro: Type-safe configuration with IntelliSense. Validation at startup catches misconfiguration early.
- Pro: Each module owns its section name, no collisions.
- Con: Adding a new module means adding a new `appsettings.json` section.

**Example:**

```csharp
// In Starter.WebApi.Auth/Options/JwtOptions.cs
public sealed class JwtOptions
{
    [Required] public required string Secret { get; set; }
    [Required] public required string Issuer { get; set; }
    [Required] public required string Audience { get; set; }
    public int ExpirationMinutes { get; set; } = 60;
}

// In Starter.WebApi.Auth/Extensions/AuthServiceExtensions.cs
public static class AuthServiceExtensions
{
    public static IServiceCollection AddStarterAuth(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<JwtOptions>()
            .BindConfiguration("Auth:Jwt")
            .ValidateDataAnnotations()
            .ValidateOnStart();

        // Register auth services...
        return services;
    }
}

// In appsettings.json (Host)
{
    "Auth": {
        "Jwt": {
            "Secret": "development-secret-min-32-chars-long!!",
            "Issuer": "Starter.WebApi",
            "Audience": "Starter.WebApi.Clients",
            "ExpirationMinutes": 60
        },
        "Google": {
            "ClientId": "",
            "ClientSecret": ""
        }
    }
}
```

### Pattern 3: Response Envelope via Action Filter

**What:** A global MVC action filter wraps all successful controller responses in a standardized `ApiResponse<T>` envelope. Error responses flow through ProblemDetails (RFC 7807). This keeps controllers clean while ensuring consistent response shapes.

**When to use:** For all controller-based API endpoints.

**Trade-offs:**
- Pro: Controllers return raw types, envelope is applied automatically.
- Pro: Clients always receive the same shape (`{ data, message, statusCode }`).
- Con: May interfere with endpoints that need raw response control (e.g., file downloads). Needs an opt-out attribute.

**Example:**

```csharp
// In Starter.WebApi.Shared/Models/ApiResponse.cs
public sealed class ApiResponse<T>
{
    public T? Data { get; init; }
    public string Message { get; init; } = "Success";
    public int StatusCode { get; init; } = 200;
}

// In Starter.WebApi.Api/Filters/ApiResponseWrapperFilter.cs
public sealed class ApiResponseWrapperFilter : IAsyncResultFilter
{
    public async Task OnResultExecutionAsync(
        ResultExecutingContext context,
        ResultExecutionDelegate next)
    {
        if (context.Result is ObjectResult objectResult
            && objectResult.Value is not ProblemDetails)
        {
            var wrapped = new ApiResponse<object>
            {
                Data = objectResult.Value,
                StatusCode = objectResult.StatusCode ?? 200
            };
            objectResult.Value = wrapped;
        }
        await next();
    }
}
```

### Pattern 4: Dual Extension Methods (Services + Middleware)

**What:** Modules that contribute both DI registrations and middleware expose two extension methods: `AddStarter{Module}` on `IServiceCollection` for service registration, and `UseStarter{Module}` on `WebApplication` for middleware insertion. This keeps the two concerns separated and makes the host's Program.cs explicit about what registers services vs. what inserts into the request pipeline.

**When to use:** Any module that needs to insert middleware (Diagnostics, Logging, Api rate limiting, compression).

**Trade-offs:**
- Pro: Host controls middleware order explicitly. No hidden middleware registration buried inside `AddX()`.
- Pro: Clear distinction between build-time (services) and run-time (pipeline) configuration.
- Con: Two calls per module in Program.cs rather than one. Acceptable because middleware ordering is critical.

## Data Flow

### Request Flow

```
HTTP Request
    |
    v
[ExceptionHandler Middleware]  -- Catches all unhandled exceptions
    |
    v
[HTTPS Redirection]
    |
    v
[Serilog Request Logging]     -- Logs request start, enriches log context
    |
    v
[Routing]                      -- Matches route to endpoint
    |
    v
[Rate Limiter]                 -- Applies rate limit policy (per-route or global)
    |
    v
[CORS]                         -- Validates origin
    |
    v
[Authentication]               -- Validates JWT / cookie, sets ClaimsPrincipal
    |
    v
[Authorization]                -- Checks [Authorize] policies
    |
    v
[Response Compression]         -- Negotiates Gzip/Brotli
    |
    v
[Controller Action]
    |
    +-- FluentValidation (via filter or manual) validates request model
    |
    +-- Service layer (injected from module DI registrations)
    |
    +-- EF Core DbContext (from Data module) queries/writes database
    |
    +-- IMemoryCache / IDistributedCache (from Caching module)
    |
    v
[ApiResponseWrapper Filter]    -- Wraps result in ApiResponse<T> envelope
    |
    v
HTTP Response
```

### Configuration Flow

```
appsettings.json + appsettings.{Environment}.json
    |
    v
IConfiguration (built by Host)
    |
    +--- GetSection("Auth:Jwt")       --> JwtOptions          (Auth module binds)
    +--- GetSection("Auth:Google")    --> GoogleAuthOptions    (Auth module binds)
    +--- GetSection("Logging")        --> LoggingOptions       (Logging module binds)
    +--- GetSection("Database")       --> DatabaseOptions      (Data module binds)
    +--- GetSection("Caching")        --> CacheOptions         (Caching module binds)
    +--- GetSection("Api:Cors")       --> CorsOptions          (Api module binds)
    +--- GetSection("Api:RateLimit")  --> RateLimitOptions     (Api module binds)
    +--- GetSection("Api:Swagger")    --> SwaggerOptions       (Api module binds)
    +--- GetSection("Diagnostics")    --> DiagnosticsOptions   (Diagnostics module binds)
    |
    v
IOptions<T> / IOptionsSnapshot<T> / IOptionsMonitor<T>
    |
    v
Injected into services that need configuration
```

### Project Reference Graph (Dependency Direction)

```
Starter.WebApi (Host)
    |
    +--- references ---> Starter.WebApi.Auth
    +--- references ---> Starter.WebApi.Logging
    +--- references ---> Starter.WebApi.Diagnostics
    +--- references ---> Starter.WebApi.Data
    +--- references ---> Starter.WebApi.Api
    +--- references ---> Starter.WebApi.Caching
    |
    Each module above:
    +--- references ---> Starter.WebApi.Shared (common types)

    No module references another module (except through Shared).
    Shared references nothing within the solution.
```

### Key Data Flows

1. **Auth token flow:** Request arrives with `Authorization: Bearer {token}` header -> Authentication middleware validates JWT using `JwtOptions` (secret, issuer, audience) -> Sets `HttpContext.User` as `ClaimsPrincipal` -> Authorization middleware checks `[Authorize]` attribute policies -> Controller receives authenticated user.

2. **Configuration flow:** Host loads `appsettings.json` -> Each module's `AddStarter{Module}` extension method calls `BindConfiguration("SectionName")` -> Runtime resolves `IOptions<T>` per module -> Module services consume their own options type.

3. **Error flow:** Exception thrown anywhere in pipeline -> `GlobalExceptionMiddleware` catches it -> Logs via Serilog -> Returns RFC 7807 `ProblemDetails` JSON response -> Client receives standardized error shape (not the response envelope, but ProblemDetails).

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Local dev / single user | SQLite database (zero config). In-memory caching only. Console log sink. This is the default configuration. |
| Small deployment (1-100 users) | Swap to SQL Server or PostgreSQL via `DatabaseOptions.Provider`. Add file or Seq log sink. No architecture changes needed. |
| Medium deployment (100-10K users) | Switch `IMemoryCache` to `IDistributedCache` with Redis. Rate limiting policies become important. Consider splitting read/write DbContexts. |
| Large deployment (10K+) | Beyond starter scope. At this point, extract modules into separate services if needed. The modular boundary makes this extraction straightforward. |

### Scaling Priorities

1. **First bottleneck: Database.** SQLite is single-writer. Switch to SQL Server/PostgreSQL early for concurrent write workloads. The `DatabaseOptions.Provider` switch makes this a config change, not a code change.
2. **Second bottleneck: Caching.** In-memory cache does not share across instances. When running multiple app instances behind a load balancer, switch to distributed cache (Redis).

## Anti-Patterns

### Anti-Pattern 1: Shared Project Becomes a Dumping Ground

**What people do:** Put services, utilities, helpers, and business logic into `Starter.WebApi.Shared` because "multiple modules need it."
**Why it's wrong:** Shared becomes a God project that everything depends on. Changes to Shared cascade everywhere. Module boundaries erode.
**Do this instead:** Shared contains only types that define contracts between modules: response envelope model, config section name constants, and marker interfaces. If two modules need a utility, consider whether it truly belongs in both or if one module should expose it through an interface in Shared.

### Anti-Pattern 2: Module-to-Module Direct References

**What people do:** `Starter.WebApi.Auth` references `Starter.WebApi.Data` directly to access the DbContext.
**Why it's wrong:** Creates a dependency web. Removing one module breaks another. Defeats the "remove one line" principle.
**Do this instead:** If Auth needs a DbContext, it defines its own or extends the shared one through EF Core's `IEntityTypeConfiguration` pattern. Alternatively, Auth defines an interface in Shared (e.g., `IUserStore`) and Data implements it. The host's DI wiring connects them.

### Anti-Pattern 3: Hiding Middleware Inside AddServices

**What people do:** The `AddStarterAuth(IServiceCollection)` method also calls `app.UseAuthentication()` internally.
**Why it's wrong:** Middleware ordering is invisible to the host. The host cannot control where Authentication middleware sits in the pipeline. Debugging middleware order issues becomes a nightmare.
**Do this instead:** Separate service registration (`AddStarter*`) from middleware registration (`UseStarter*`). The host calls both explicitly, maintaining full control over pipeline order.

### Anti-Pattern 4: Over-Abstracting with IModule Auto-Discovery

**What people do:** Create an `IModule` interface and use reflection to auto-discover and register all modules at startup.
**Why it's wrong:** For a personal starter template with 6-7 modules, auto-discovery adds complexity without value. It hides what is registered, makes debugging harder, and removes the explicit "one line per module" property that makes Program.cs scannable. Auto-discovery makes sense at 20+ modules; it is over-engineering at 7.
**Do this instead:** Explicit extension method calls in Program.cs. Each line is visible, removable, and debuggable.

### Anti-Pattern 5: Circular Configuration Dependencies

**What people do:** Module A reads configuration that depends on Module B being configured first, creating implicit startup ordering requirements.
**Why it's wrong:** Modules should be independently configurable. If removing Module B breaks Module A's configuration binding, the "independently removable" property is violated.
**Do this instead:** Each module binds its own configuration section independently. If cross-module configuration is needed (rare), use `IOptions<T>` injection at runtime rather than configuration-time dependencies.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Host --> All Modules | Extension method calls (build time), DI resolution (runtime) | One-directional. Modules never reference the Host. |
| Module --> Shared | Project reference for shared types | Shared is the only cross-module dependency allowed. |
| Auth --> Data | Through shared interface (e.g., `IUserStore` in Shared, implemented in Data) | Auth must not directly reference Data. If Auth needs its own tables, it defines its own DbContext or uses `IEntityTypeConfiguration` registered by the Host. |
| Api (Validation) --> Controllers | FluentValidation registered globally or per-endpoint via DI | Validators live in Api module, resolved by the validation pipeline filter. |
| Diagnostics --> All | ExceptionHandler middleware wraps entire pipeline | Must be first in middleware order. All modules benefit without referencing Diagnostics. |

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| SQLite / SQL Server / PostgreSQL | EF Core provider, configured via `DatabaseOptions.Provider` | Provider switching is config-driven. Only one provider active at runtime. |
| Google OAuth | `Microsoft.AspNetCore.Authentication.Google` | ClientId/ClientSecret from `appsettings.json`. Removable by removing the Google extension call within `AddStarterAuth`. |
| Seq / Application Insights | Serilog sink packages | Configured via `LoggingOptions.Sinks`. Sinks are additive. |
| Redis (optional) | `Microsoft.Extensions.Caching.StackExchangeRedis` | Only needed when switching from in-memory to distributed cache. Connection string in `CacheOptions`. |

## Middleware Ordering Reference

The following order is derived from the official ASP.NET Core 10 documentation (Microsoft Learn, updated 2026-02-04). This is the canonical ordering for this project's middleware stack:

```
1.  UseExceptionHandler / UseStarterDiagnostics()  -- Must be first (catches all exceptions)
2.  UseHsts                                         -- HTTPS strict transport (production only)
3.  UseHttpsRedirection                             -- Redirect HTTP to HTTPS
4.  UseStarterLogging / UseSerilogRequestLogging()  -- Log each request (after HTTPS redirect)
5.  UseRouting                                      -- Match request to endpoint
6.  UseRateLimiter / UseStarterRateLimiting()       -- Apply rate limit policies
7.  UseCors                                         -- Validate CORS origin
8.  UseAuthentication                               -- Validate credentials, set ClaimsPrincipal
9.  UseAuthorization                                -- Check [Authorize] policies
10. UseResponseCompression / UseStarterCompression()-- Negotiate compression encoding
11. MapControllers + MapStarterHealthChecks()        -- Terminal endpoint mapping
```

**Critical ordering rules (source: Microsoft Learn ASP.NET Core Middleware):**
- ExceptionHandler MUST be first to catch exceptions from all subsequent middleware
- Routing MUST come before Authentication/Authorization so the system knows which endpoint's policies to evaluate
- Authentication MUST come before Authorization (authorization depends on authenticated identity)
- CORS MUST come after Routing and before Authentication
- Rate Limiter goes after Routing so per-endpoint policies can be resolved

## Build Order (Suggested Implementation Phases)

The project reference graph dictates a natural build order:

```
Phase 1: Starter.WebApi.Shared        (no dependencies, foundation types)
     |
Phase 2: Starter.WebApi (Host)        (bare Program.cs with grouped sections)
     |
Phase 3: Starter.WebApi.Diagnostics   (exception handling + health checks, needed early)
     |
Phase 4: Starter.WebApi.Logging       (Serilog, depends on Shared only)
     |
Phase 5: Starter.WebApi.Data          (EF Core + SQLite, depends on Shared)
     |
Phase 6: Starter.WebApi.Auth          (Identity + JWT + Google, depends on Shared and Data indirectly)
     |
Phase 7: Starter.WebApi.Caching       (depends on Shared only)
     |
Phase 8: Starter.WebApi.Api           (versioning, Swagger, CORS, validation, rate limiting, compression)
     |
Phase 9: Tests                        (unit + integration, depends on everything above)
```

**Build order rationale:**
- Shared first because every module depends on it.
- Host second because you need a running app to verify each module as it is added.
- Diagnostics third because exception handling and health checks provide immediate development feedback.
- Logging fourth because all subsequent development benefits from structured logging.
- Data fifth because Auth depends on a user store and the DbContext is a common integration point.
- Auth sixth because it depends on Data for user storage and is complex enough to warrant its own phase.
- Caching seventh because it is independent and lower priority than auth/data.
- Api eighth because it layers on top of everything (versioning, Swagger, validation all require existing controllers and services to be meaningful).
- Tests last because they exercise the full stack.

## Sources

- [ASP.NET Core Middleware - Microsoft Learn (aspnetcore-10.0)](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-10.0) - Official middleware ordering reference (updated 2026-02-04). HIGH confidence.
- [Options pattern guidance for .NET library authors - Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-library-authors) - Official IOptions pattern for library authors. HIGH confidence.
- [Options pattern in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/options?view=aspnetcore-10.0) - Official options pattern documentation. HIGH confidence.
- [Introducing SLNX support in .NET CLI - .NET Blog](https://devblogs.microsoft.com/dotnet/introducing-slnx-support-dotnet-cli/) - SLNX format is default in .NET 10. HIGH confidence.
- [Modular Architecture in ASP.NET Core - codewithmukesh](https://codewithmukesh.com/blog/modular-architecture-in-aspnet-core/) - Extension method composition patterns. MEDIUM confidence (community source, patterns verified against official docs).
- [Service Collection Extension Pattern - DotNet Full Stack Dev](https://dotnetfullstackdev.medium.com/service-collection-extension-pattern-in-net-core-with-item-services-6db8cf9dcfd6) - IServiceCollection extension method pattern. MEDIUM confidence.
- [Modular Monoliths With ASP.NET Core - Thinktecture](https://www.thinktecture.com/en/asp-net-core/modular-monolith/) - Module boundary patterns. MEDIUM confidence.
- [What every ASP.NET Core Web API project needs - IServiceCollection Extension](https://dev.to/moesmp/what-every-asp-net-core-web-api-project-needs-part-6-iservicecollection-extension-19g9) - Multi-project DI registration. MEDIUM confidence.

---
*Architecture research for: Modular .NET 10 Web API Starter Template*
*Researched: 2026-03-18*
