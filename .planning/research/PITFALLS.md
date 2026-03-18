# Pitfalls Research

**Domain:** Modular .NET 10 Web API Starter Template
**Researched:** 2026-03-18
**Confidence:** HIGH (majority verified via Microsoft official docs and authoritative library documentation)

## Critical Pitfalls

### Pitfall 1: Middleware Ordering Causes Silent Auth Failures

**What goes wrong:**
Middleware placed in the wrong order silently fails rather than throwing an error. `UseRateLimiter` before `UseRouting` means endpoint-specific rate limits never apply. `UseRateLimiter` before `UseAuthentication` means `HttpContext.User` is always anonymous, so per-user partition keys silently fall back to the anonymous bucket. `UseResponseCompression` after `UseStaticFiles` means static files skip compression entirely. None of these produce errors -- the app runs but features are silently broken.

**Why it happens:**
In a modular template where each module contributes its own middleware via `app.Use{Feature}()` calls, the ordering in `Program.cs` becomes the template author's responsibility, and each module is independently developed without seeing its neighbors. .NET 10's `WebApplication` auto-registers `UseAuthentication` and `UseAuthorization` if you don't call them explicitly, which means adding an explicit call at the wrong position can actually override the correct auto-placement.

**How to avoid:**
Define the canonical middleware order in `Program.cs` as a documented skeleton with comment blocks. Do NOT let module extension methods call `app.Use*()` middleware internally -- keep all `Use*` calls visible in `Program.cs` where ordering is explicit. The Microsoft-documented order for .NET 10 is:

```
1. ExceptionHandler / DeveloperExceptionPage
2. HSTS
3. HttpsRedirection
4. ResponseCompression (before StaticFiles)
5. StaticFiles
6. CookiePolicy
7. Routing
8. RateLimiter (after Routing, after Authentication for per-user limits)
9. RequestLocalization
10. CORS
11. Authentication
12. Authorization
13. Session
14. ResponseCaching
15. Endpoint mapping (MapControllers, MapHealthChecks, etc.)
```

**Warning signs:**
- Rate limiting "not working" despite correct policy configuration
- Authenticated endpoints returning 401 for valid tokens
- Response sizes unchanged after enabling compression
- CORS headers missing on preflight requests

**Phase to address:**
Phase 1 (Solution scaffold / Program.cs structure). The middleware skeleton must be correct from day one because every subsequent module depends on it.

---

### Pitfall 2: JWT + Identity Cookie Scheme Conflict

**What goes wrong:**
When ASP.NET Core Identity is registered alongside JWT Bearer authentication, Identity sets cookie authentication as the default scheme. API endpoints expecting JWT tokens get redirected to a login page (302) or silently challenged with cookies instead of returning 401. Setting JWT as the default scheme breaks Identity's scaffolded pages. The `[Authorize]` attribute binds to the first/default scheme, so endpoints either work for JWT or cookies, never cleanly for both.

**Why it happens:**
ASP.NET Core Identity calls `AddAuthentication().AddCookie()` internally and sets itself as the default. Adding `.AddJwtBearer()` adds a second scheme but doesn't change the default. Developers expect `[Authorize]` to "just work" for both, but it only tries the default scheme unless explicitly told otherwise.

**How to avoid:**
Use a `PolicyScheme` as the default authentication scheme with a `ForwardDefaultSelector` that inspects the request: if an `Authorization: Bearer` header is present, forward to the JWT scheme; otherwise, forward to the cookie/Identity scheme. Then update the default authorization policy to accept both schemes:

```csharp
services.AddAuthentication(options =>
{
    options.DefaultScheme = "MultiScheme";
})
.AddPolicyScheme("MultiScheme", null, options =>
{
    options.ForwardDefaultSelector = context =>
    {
        string authorization = context.Request.Headers.Authorization;
        if (!string.IsNullOrEmpty(authorization) && authorization.StartsWith("Bearer "))
            return JwtBearerDefaults.AuthenticationScheme;
        return IdentityConstants.ApplicationScheme;
    };
})
.AddJwtBearer(...)
.AddGoogle(...)
```

Additionally, ensure that the auth module's `AddAuth(IServiceCollection)` extension method registers all schemes in a single call chain, never split across modules where ordering is ambiguous.

**Warning signs:**
- API clients receiving 302 redirects instead of 401
- Swagger "Authorize" button works but requests fail with cookies
- `HttpContext.User.Identity.IsAuthenticated` is false despite valid JWT
- Google OAuth callback works but subsequent API calls fail

**Phase to address:**
Phase 2 (Auth module). This is the single most complex module and the scheme conflict must be resolved before any endpoint authorization work begins.

---

### Pitfall 3: EF Core Multi-Provider Migrations Are Incompatible

**What goes wrong:**
Migrations generated against SQLite produce SQLite-specific column types (e.g., `HasColumnType("TEXT")`) that crash on SQL Server. Conversely, SQL Server migrations use `nvarchar(max)` which SQLite doesn't understand. A single set of migrations cannot be applied to multiple providers. SQLite also lacks support for `DateTimeOffset`, `decimal` (comparison/ordering), `TimeSpan`, and `ulong` -- EF Core can read/write these types, but queries using comparison or ordering fail or fall back to client evaluation.

**Why it happens:**
EF Core migrations are provider-specific by design. The migration scaffolder uses the currently-configured provider's type mappings. Developers assume migrations are "database-agnostic" because they look like C# code, but internally they carry provider-specific metadata. The SQLite provider also has limited `ALTER TABLE` support -- many schema operations require a full table rebuild.

**How to avoid:**
Maintain separate migration assemblies per provider. Use a provider-derived DbContext pattern:

```
Starter.WebApi.Data/
  AppDbContext.cs          (abstract or shared OnModelCreating)
  Sqlite/
    SqliteAppDbContext.cs  (overrides OnConfiguring for SQLite)
    Migrations/            (SQLite-specific migrations)
  SqlServer/
    SqlServerAppDbContext.cs
    Migrations/
  Postgres/
    PostgresAppDbContext.cs
    Migrations/
```

Register the correct context via configuration. Avoid provider-specific data annotations -- use Fluent API in `OnModelCreating` where you can branch by provider. Avoid `DateTimeOffset` in entity models; use `DateTime` with UTC normalization. Use `double` instead of `decimal` if SQLite precision is acceptable, or add a value converter.

Additionally, be aware of the SQLite `__EFMigrationsLock` table issue: if a migration fails catastrophically, the lock table may not be released, blocking all subsequent migrations until manually deleted.

**Warning signs:**
- `NotSupportedException` when running `dotnet ef database update` against a different provider
- Client-side query evaluation warnings in logs (indicates SQLite falling back)
- Migration diffs that include `HasColumnType` with provider-specific types
- Tests passing on SQLite but production queries failing on SQL Server

**Phase to address:**
Phase 3 (Data/EF Core module). Must be designed correctly before the first migration is created, because retrofitting separate migration assemblies after models exist is painful.

---

### Pitfall 4: Serilog Two-Stage Bootstrap Misconfiguration

**What goes wrong:**
The bootstrap logger and the final hosted logger are completely separate instances. Configuration applied to one does not carry to the other. `ReadFrom.Configuration()` has no effect in the bootstrap stage because `IConfiguration` hasn't been built yet. If the bootstrap logger writes to Console but the final logger doesn't, logs appear during startup then vanish. If the final logger isn't configured with `builder.Services.AddSerilog()`, the default ASP.NET Core logging competes with Serilog, producing duplicate or missing log entries. Missing `Log.CloseAndFlush()` in a `finally` block means fatal startup exceptions may never be written.

**Why it happens:**
Serilog's two-stage pattern exists because you need logging before the host is built (`IConfiguration`, DI, etc. aren't available yet). The bootstrap logger is a temporary fallback. Developers configure it "fully" thinking it persists, or skip it thinking the hosted logger handles everything, missing startup crash logging.

**How to avoid:**
Use the canonical two-stage pattern with `AddSerilog` (not the older `UseSerilog` on `Host`):

```csharp
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()       // Bootstrap: minimal, hardcoded sinks only
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Services.AddSerilog((services, lc) => lc
        .ReadFrom.Configuration(builder.Configuration)
        .ReadFrom.Services(services));

    var app = builder.Build();
    // ... middleware ...
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

The logging module's `AddSerilog` extension should accept `IConfiguration` and call `ReadFrom.Configuration()` within the hosted logger callback. Never use string interpolation in log message templates (`Log.Information($"User {userId}")` -- use structured templates: `Log.Information("User {UserId}", userId)`).

**Warning signs:**
- Startup exceptions not appearing in any log sink
- Logs appearing in Console during startup but disappearing once the app is "ready"
- Duplicate log entries (one from Serilog, one from Microsoft.Extensions.Logging)
- `ReadFrom.Configuration` silently producing no sinks

**Phase to address:**
Phase 2 or 3 (Logging/Observability module). Should be one of the first modules built since all other modules depend on logging for debugging.

---

### Pitfall 5: IOptions Validation Deferred Until First Access

**What goes wrong:**
Configuration binds to `IOptions<T>` silently, even when required properties are null or invalid. Section name mismatches between `appsettings.json` keys and `ConfigurationSectionName` constants cause the entire options object to bind with default/null values -- no exception, no warning. The app starts successfully and fails at runtime when the first code path accesses the misconfigured option, often in production under specific conditions.

**Why it happens:**
`IOptions<T>` is lazy by default. Configuration binding is case-insensitive but section names must match exactly. There's no compile-time verification that appsettings sections exist or that values are valid. Developers add `services.Configure<T>(configuration.GetSection("SectionName"))` and assume it's wired up.

**How to avoid:**
Every module's `Add{Module}` extension method must use `ValidateDataAnnotations().ValidateOnStart()`:

```csharp
services.AddOptions<AuthOptions>()
    .BindConfiguration(AuthOptions.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

Add `[Required]` attributes on non-optional properties. For complex validation, implement `IValidateOptions<T>`. Use the compile-time source generator `[OptionsValidator]` attribute in .NET 10 for zero-reflection validation. Never use `IOptionsSnapshot<T>` in singleton services (lifetime mismatch) -- use `IOptionsMonitor<T>` instead.

**Warning signs:**
- Options properties are null/default at runtime with no startup error
- Tests pass with in-memory configuration but production fails
- Adding a new appsettings section and forgetting to bind it
- `IOptionsSnapshot` injected into a singleton service throws at runtime

**Phase to address:**
Phase 1 (Solution scaffold / shared abstractions). Establish the `ValidateOnStart()` convention as a template-wide standard before any module is built.

---

### Pitfall 6: Module Cross-Coupling via Shared Types

**What goes wrong:**
Modules that should be independently removable develop hidden dependencies. The Auth module references types from the Data module directly. The Logging module depends on Auth to enrich logs with user claims. Removing one project reference causes cascading build failures across the solution, defeating the entire modular design premise.

**Why it happens:**
It's natural to share entity types, DTOs, or interfaces across modules for convenience. The .NET project reference system doesn't enforce one-way dependency graphs unless you're deliberate. "Just add a reference" is easy; untangling circular dependencies is hard.

**How to avoid:**
Define strict dependency rules:
- **Host project** (`Starter.WebApi`) references all modules but modules never reference the host
- **Modules** never reference each other directly
- **Shared kernel** (`Starter.WebApi.Common`) contains only: interfaces, base types, extension methods, constants. Never entities, never business logic
- Module-to-module communication uses interfaces defined in `Common` and resolved via DI

Make implementation types `internal` within each module. The only public surface should be the `Add{Module}(IServiceCollection)` and `Use{Module}(IApplicationBuilder)` extension methods, plus any interfaces/DTOs the host needs.

Validate with an architectural test (NetArchTest or ArchUnitNET):

```csharp
[Fact]
public void Auth_Module_Should_Not_Reference_Logging_Module()
{
    Types.InAssembly(typeof(AuthExtensions).Assembly)
        .ShouldNot()
        .HaveDependencyOn("Starter.WebApi.Logging")
        .GetResult()
        .IsSuccessful.Should().BeTrue();
}
```

**Warning signs:**
- More than 2 project references in any module's `.csproj` (itself + Common)
- Removing a module's `AddX()` call produces build errors in other modules
- Entity types living in a module but referenced from 3+ other modules
- Circular dependency warnings from IDE/build tools

**Phase to address:**
Phase 1 (Solution scaffold). The project structure and dependency rules must be established before any module is implemented, as retrofitting modularity is exponentially harder.

---

### Pitfall 7: FluentValidation Auto-Validation Is Deprecated

**What goes wrong:**
Developers install `FluentValidation.AspNetCore` and wire up automatic model validation via the MVC pipeline. This package is deprecated since FluentValidation v11, removed in v12. The auto-validation pipeline doesn't support async validators (the ASP.NET Core validation pipeline is synchronous). It also contained breaking changes across nearly every ASP.NET Core release, making it a maintenance liability.

**Why it happens:**
Countless tutorials and Stack Overflow answers still recommend `FluentValidation.AspNetCore` with `AddFluentValidation()`. The auto-validation approach feels ergonomic ("validators just work"), so developers reach for it without checking deprecation status.

**How to avoid:**
Use the `FluentValidation` package only (not `.AspNetCore`). Register validators from assemblies:

```csharp
services.AddValidatorsFromAssemblyContaining<CreateUserValidator>();
```

Call validation explicitly: inject `IValidator<T>` and call `ValidateAsync()` manually. For minimal APIs, create a reusable `ValidationFilter<T>` endpoint filter. For controllers, create an action filter that resolves `IValidator<T>` from DI and returns `ValidationProblem()` (RFC 7807 Problem Details) on failure.

This approach supports async validators, makes validation call sites visible, and integrates cleanly with the Problem Details middleware.

**Warning signs:**
- NuGet restore warnings about deprecated package `FluentValidation.AspNetCore`
- Async validators silently not executing
- Validation behavior changing after ASP.NET Core version upgrades

**Phase to address:**
Phase 4 (Validation module). Build explicit validation with Problem Details integration from the start.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single migration assembly for all providers | Simpler project structure, faster initial setup | Migrations break when switching providers; must regenerate all migrations | Never -- cost of separate assemblies is low and paid once |
| `services.Configure<T>()` without `ValidateOnStart()` | Fewer lines of code per module registration | Silent misconfiguration in production, runtime null refs | Never -- `ValidateOnStart()` is a one-liner |
| Making module types `public` by default | Avoids thinking about visibility, easier cross-module access | Accidental coupling, impossible to remove modules cleanly | Never for a modular template; always prefer `internal` |
| Hardcoding Serilog sinks instead of `ReadFrom.Configuration` | Faster initial setup, no JSON config to write | Every sink change requires code change and recompile | Only for the bootstrap logger (by design) |
| Sharing `AppDbContext` entity types across modules | Convenient data access from any module | Tight coupling to data layer, migrations affect all modules | Only acceptable for a small starter; consider module-owned DTOs at scale |
| Using `IOptions<T>` everywhere instead of `IOptionsMonitor<T>` | Simpler, no change-tracking to think about | Cannot reload config without restart, breaks if injected into singletons incorrectly | Acceptable for configs that never change at runtime |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Google OAuth callback | Forgetting to register the `/signin-google` callback path, or placing it behind auth middleware that rejects unauthenticated requests | Ensure callback path is not blocked by authorization. Use `ForwardedHeaders` middleware if behind a reverse proxy to preserve HTTPS scheme in redirect URIs |
| EF Core Health Checks | Using `AddDbContextCheck<AppDbContext>()` which shares the request's DbContext scope, causing threading issues under load | Create a dedicated scope for health check DbContext queries. Set explicit timeout (5s) on the health check to prevent hung checks from blocking readiness probes |
| Swagger + JWT | Registering the security definition but forgetting `SecurityRequirement`, so the "Authorize" button appears but tokens are never sent | Add both `AddSecurityDefinition("Bearer", ...)` and `AddSecurityRequirement(...)` in Swagger configuration |
| Rate Limiter + Authenticated Users | Placing `UseRateLimiter` before `UseAuthentication`, so `HttpContext.User` is always anonymous and per-user rate limit partitions never differentiate users | Always place `UseRateLimiter` after `UseAuthentication` and `UseRouting` |
| Response Compression + HTTPS | Enabling Brotli/Gzip compression over HTTPS without understanding BREACH attack risk | Compression over HTTPS is safe for API JSON responses (not user-secret-bearing HTML). Explicitly configure `CompressionProviderOptions` and only compress known-safe MIME types |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `IOptionsSnapshot<T>` in hot paths | Per-request config rebuild overhead, visible in profiling under load | Use `IOptions<T>` for static config, `IOptionsMonitor<T>` for dynamic config that must respond to reloads | > 1K req/s where config is accessed per-request |
| EF Core `DbContext` not using pooling | New DbContext per request incurs connection setup overhead | Use `AddDbContextPool<T>()` instead of `AddDbContext<T>()` | > 500 concurrent requests |
| Serilog string interpolation in log calls | String allocation on every call even when log level is disabled | Use message templates: `Log.Debug("Processing {Id}", id)` not `Log.Debug($"Processing {id}")` | High-throughput endpoints (1K+ req/s), especially at Debug/Verbose level |
| Health check queries without timeout | A hung database connection blocks the health endpoint indefinitely, causing orchestrators to mark the pod unhealthy after their own timeout, then restart it | Set explicit `Timeout = TimeSpan.FromSeconds(5)` on health check registration | Any production deployment behind a load balancer or orchestrator |
| Missing `AsNoTracking()` on read-only queries | EF Core tracks every entity by default, consuming memory and CPU for change detection | Use `AsNoTracking()` on read-only queries, or configure `QueryTrackingBehavior.NoTracking` as DbContext default | > 100 entities returned per query |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing JWT signing key in `appsettings.json` committed to source control | Key compromise enables token forgery for all users | Use user-secrets in dev, environment variables or Key Vault in production. Add `appsettings.*.json` patterns to `.gitignore` selectively |
| Not validating JWT `Audience` and `Issuer` claims | Tokens from other applications/tenants are accepted | Always set `ValidateAudience = true` and `ValidateIssuer = true` in `TokenValidationParameters` |
| Exposing detailed error information in Problem Details | Stack traces and internal exception messages leak implementation details | Use `IExceptionHandler` that maps exceptions to safe Problem Details. Only include `detail` field with safe messages. Enable stack traces only in Development environment |
| CORS with `AllowAnyOrigin()` + `AllowCredentials()` | Browsers block this combination (spec violation), but misconfigured CORS may allow unintended cross-origin access | Explicitly list allowed origins per environment in `appsettings.json`. Never use `AllowAnyOrigin()` with credentials |
| Not setting token expiration or using long-lived JWTs | Stolen tokens remain valid indefinitely | Set short access token expiry (15-60 min). Implement refresh token rotation. Consider token revocation for sensitive operations |

## "Looks Done But Isn't" Checklist

- [ ] **Auth module:** Cookie + JWT dual scheme works -- verify API returns 401 (not 302 redirect) for missing/invalid JWT tokens
- [ ] **Auth module:** Google OAuth flow completes AND issues a JWT -- verify the entire flow from `/login/google` through callback to JWT issuance, not just "Google login works"
- [ ] **EF Core module:** Migrations apply to ALL target providers -- run `dotnet ef database update` against SQLite AND SQL Server, not just the dev default
- [ ] **Serilog module:** Startup crash logging works -- throw an exception before `app.Run()` and verify it appears in the configured sink, not just Console
- [ ] **Rate limiting:** Per-user limits differentiate authenticated users -- test with 2 different JWT tokens and verify independent rate limit counters
- [ ] **Health checks:** `/health/ready` actually tests DB connectivity under load -- simulate a database timeout and verify the health endpoint returns `Degraded` or `Unhealthy` within its timeout
- [ ] **Validation:** Async validators execute -- create a validator with an async rule (e.g., unique email check) and verify it runs, since sync-only pipelines silently skip async rules
- [ ] **Module removal:** Removing one `Add{Module}()` call and its project reference produces zero build errors -- actually test this for each module
- [ ] **Options validation:** Missing/invalid `appsettings.json` section prevents startup -- delete a module's config section and verify the app fails to start with a clear message
- [ ] **Response envelope:** Error responses also use the standard envelope -- verify that validation errors, 404s, and unhandled exceptions all return consistent Problem Details format, not just success responses

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong middleware order | LOW | Reorder calls in Program.cs. Run integration tests against all auth/rate-limit/compression scenarios |
| JWT/Cookie scheme conflict | MEDIUM | Introduce PolicyScheme, update all `[Authorize]` attributes that specify schemes, re-test all auth flows |
| Single migration assembly | HIGH | Create per-provider DbContext subclasses, regenerate all migrations per provider, verify data integrity |
| Module cross-coupling | HIGH | Extract shared types to Common, change public types to internal, add architectural tests, fix all build errors |
| Missing `ValidateOnStart` | LOW | Add `.ValidateOnStart()` to each Options registration. Run app with intentionally broken config to verify |
| Serilog misconfiguration | LOW | Apply canonical two-stage pattern. Test by throwing before `app.Run()` |
| Deprecated FluentValidation.AspNetCore | MEDIUM | Remove package, replace auto-validation with manual `IValidator<T>` injection, add endpoint filters |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Middleware ordering | Phase 1: Solution scaffold | Integration test that verifies request passes through middleware in correct order (e.g., rate-limited auth'd request returns 429 not 401) |
| JWT + Cookie scheme conflict | Phase 2: Auth module | Test: API request with Bearer token returns 200; same endpoint without token returns 401 (not 302) |
| EF Core multi-provider migrations | Phase 3: Data module | CI step that runs `dotnet ef database update` against SQLite and at least one other provider |
| Serilog two-stage bootstrap | Phase 2-3: Logging module | Test: throw exception in `Program.cs` before `app.Run()`, verify exception appears in configured sink |
| IOptions ValidateOnStart | Phase 1: Solution scaffold (convention), every module (enforcement) | Test: remove required config section, verify app crashes on startup with descriptive error |
| Module cross-coupling | Phase 1: Solution scaffold | Architectural unit test (NetArchTest) asserting no module-to-module references. Manual test: remove each module and verify clean build |
| FluentValidation deprecation | Phase 4: Validation module | Verify `FluentValidation.AspNetCore` package is NOT in any `.csproj`. Verify async validators execute |

## Sources

- [ASP.NET Core Middleware - Microsoft Learn (Feb 2026)](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-10.0) - Official middleware ordering documentation
- [SQLite Database Provider Limitations - EF Core - Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/providers/sqlite/limitations) - Official SQLite EF Core limitations
- [Migrations with Multiple Providers - EF Core - Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/providers) - Official multi-provider migration guidance
- [Options pattern in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/options?view=aspnetcore-10.0) - Official IOptions documentation
- [Options pattern guidance for .NET library authors - Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-library-authors) - Official library author options guidance
- [Authorize with a specific scheme - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/limitingidentitybyscheme?view=aspnetcore-10.0) - Multi-scheme auth documentation
- [Handle errors in ASP.NET Core - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-10.0) - Problem Details and IExceptionHandler
- [Rate limiting middleware - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit?view=aspnetcore-10.0) - Rate limiter ordering requirements
- [Bootstrap logging with Serilog - Nicholas Blumhardt](https://nblumhardt.com/2020/10/bootstrap-logger/) - Authoritative Serilog bootstrap pattern
- [Serilog and .NET 8.0 minimal APIs - Nicholas Blumhardt](https://nblumhardt.com/2024/04/serilog-net8-0-minimal/) - Modern Serilog integration pattern
- [FluentValidation ASP.NET Core deprecation - GitHub Issue #1960](https://github.com/FluentValidation/FluentValidation/issues/1960) - Official deprecation announcement
- [FluentValidation ASP.NET Core docs](https://docs.fluentvalidation.net/en/latest/aspnet.html) - Manual validation approach
- [Dependency injection guidelines - Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/guidelines) - DI lifetime rules
- [Global Error Handling - Milan Jovanovic](https://www.milanjovanovic.tech/blog/global-error-handling-in-aspnetcore-from-middleware-to-modern-handlers) - IExceptionHandler patterns
- [Modular Architecture in ASP.NET Core - codewithmukesh](https://codewithmukesh.com/blog/modular-architecture-in-aspnet-core/) - Module isolation patterns
- [Modular Monoliths With ASP.NET Core - Thinktecture](https://www.thinktecture.com/en/asp-net-core/modular-monolith/) - Cross-module dependency prevention

---
*Pitfalls research for: Modular .NET 10 Web API Starter Template*
*Researched: 2026-03-18*
