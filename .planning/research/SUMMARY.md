# Project Research Summary

**Project:** Starter.WebApi -- Modular .NET 10 Web API Starter Repository
**Domain:** Modular Web API boilerplate / starter template
**Researched:** 2026-03-18
**Confidence:** HIGH

## Executive Summary

This project is a modular .NET 10 Web API starter template designed around a single architectural principle: each cross-cutting concern (auth, logging, caching, etc.) lives in its own class library and can be removed by deleting one extension method call and one project reference. The research confirms that the .NET 10 ecosystem is mature and well-aligned for this goal -- nearly every concern (rate limiting, response compression, CORS, health checks, exception handling) is now handled by built-in first-party middleware, reducing external package dependencies to Serilog, FluentValidation, EF Core providers, API versioning, and the test stack. The recommended stack is exclusively HIGH confidence, with verified package versions targeting .NET 10 LTS.

The recommended approach is extension-method composition: each module exposes `AddStarter{Module}` on `IServiceCollection` and optionally `UseStarter{Module}` on `WebApplication`, called explicitly in a grouped Program.cs. A thin Shared project holds only contracts (response envelope, config section constants). No module references another module -- all cross-module communication flows through interfaces in Shared resolved via DI. This pattern is validated by analysis of 7 major open-source .NET boilerplates and Microsoft's own middleware documentation. The project's core differentiator -- true single-line module removal -- is not achieved by any analyzed competitor.

The primary risks are: (1) JWT + Identity cookie scheme conflicts that silently return 302 redirects instead of 401 responses, requiring a `PolicyScheme` with `ForwardDefaultSelector`; (2) EF Core multi-provider migration incompatibility that demands separate migration assemblies per provider from day one; and (3) module cross-coupling that erodes the removability promise unless strict dependency rules and architectural tests are enforced from the initial scaffold. All three risks are well-documented with clear prevention strategies and must be addressed in their respective build phases rather than retrofitted.

## Key Findings

### Recommended Stack

The stack is entirely .NET 10 LTS-aligned with first-party packages wherever possible. External dependencies are limited to Serilog (structured logging), FluentValidation 12 (complex validation), Asp.Versioning.Mvc 8.1.1 (API versioning), Scalar (OpenAPI UI), and the test stack (xUnit v3, NSubstitute, AwesomeAssertions). See [STACK.md](./STACK.md) for full package list with versions.

**Core technologies:**
- **.NET 10 / ASP.NET Core 10**: LTS runtime (Nov 2025 -- Nov 2028). Built-in OpenAPI 3.1, rate limiting, validation, passkey auth.
- **EF Core 10 + SQLite (dev) / SQL Server / PostgreSQL (prod)**: First-party ORM with provider-swapping via configuration. SQLite for zero-friction local dev.
- **Serilog 4.3 + Serilog.AspNetCore 10.0**: Structured logging with configurable sinks (Console, File, Seq, OpenTelemetry for App Insights). Industry standard.
- **ASP.NET Core Identity + JWT Bearer + Google OAuth**: Three-layer composable auth. First-party packages.
- **FluentValidation 12.1**: Manual `IValidator<T>` injection -- the `.AspNetCore` auto-pipeline is deprecated/removed.
- **Scalar.AspNetCore 1.2.5 + Microsoft.AspNetCore.OpenApi 10.0**: Microsoft-recommended replacement for Swagger UI. Generates OpenAPI 3.1 natively.
- **xUnit v3 + NSubstitute + AwesomeAssertions**: Test stack avoids Moq (trust concerns) and FluentAssertions (commercial license). AwesomeAssertions is the Apache 2.0 community fork.

**Key stack decisions:**
- AwesomeAssertions over FluentAssertions (no $130/dev/year license risk)
- NSubstitute over Moq (no SponsorLink controversy, cleaner API)
- Built-in rate limiting over AspNetCoreRateLimit (first-party since .NET 7)
- Serilog.Sinks.OpenTelemetry over Serilog.Sinks.ApplicationInsights (classic sink depends on deprecated SDK)
- `IExceptionHandler` over custom middleware (first-party since .NET 8, integrates with ProblemDetails)

### Expected Features

See [FEATURES.md](./FEATURES.md) for the full feature landscape with prevalence analysis across 7 boilerplates.

**Must have (table stakes -- present in 5+ of 7 analyzed boilerplates):**
- Global exception handling (RFC 7807 Problem Details)
- Structured logging (Serilog with configurable sinks)
- OpenAPI documentation (Scalar UI)
- Authentication and authorization (Identity + Google OAuth + JWT Bearer)
- EF Core data access (SQLite dev default, swappable providers)
- CORS configuration (appsettings-driven)
- Health checks (liveness, readiness, aggregate -- Kubernetes-aligned)
- FluentValidation with Problem Details integration
- Testing infrastructure (unit + integration with WebApplicationFactory)
- Strongly-typed configuration (IOptions<T> per module with ValidateOnStart)

**Should have (differentiators -- present in 1-3 of 7 boilerplates):**
- Modular class-library architecture with single-line removal (0/7 -- the core differentiator)
- API versioning with sample v1/v2 controllers (3/7)
- Rate limiting with appsettings-driven policies (2/7)
- Response compression (Gzip/Brotli, opt-in) (1/7)
- In-memory + distributed caching abstraction (1/7)
- Standardized response envelope via action filter (1/7)
- Grouped-by-concern Program.cs layout (0/7)

**Defer (v2+) / Anti-features:**
- MediatR / CQRS -- architectural opinion that should not be baked into a starter
- AutoMapper / Mapster -- hides bugs, community moving away
- Multi-tenancy, background jobs (Hangfire), Docker, CI/CD, GraphQL, OpenTelemetry/Aspire, dotnet-new template packaging, feature flags

### Architecture Approach

The solution uses a flat modular architecture: one Host project (composition root with Program.cs), one Shared project (contracts only), and 6 feature modules (Auth, Logging, Diagnostics, Data, Api, Caching) each implemented as class libraries. No module references another module. The Host references all modules. All modules reference only Shared. See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full project structure, data flow diagrams, and middleware ordering reference.

**Major components:**
1. **Starter.WebApi (Host)** -- Composition root. Calls extension methods in grouped order. Contains sample controllers. No business logic.
2. **Starter.WebApi.Shared** -- Response envelope model, config section constants, marker interfaces. Deliberately thin.
3. **Starter.WebApi.Auth** -- Identity store, Google OAuth, JWT Bearer issuance/validation. Uses PolicyScheme for dual cookie/JWT support.
4. **Starter.WebApi.Logging** -- Serilog pipeline with two-stage bootstrap. Configurable sinks via appsettings.
5. **Starter.WebApi.Diagnostics** -- Health checks (3 endpoints), global exception handler, ProblemDetails factory.
6. **Starter.WebApi.Data** -- EF Core DbContext, entity configurations, per-provider migration assemblies, provider switching via config.
7. **Starter.WebApi.Api** -- API versioning, Swagger/Scalar, CORS, rate limiting, response compression, FluentValidation, response envelope filter.
8. **Starter.WebApi.Caching** -- IMemoryCache + IDistributedCache setup with IOptions-driven config.

**Key patterns:**
- Extension method composition (AddStarter*/UseStarter* per module)
- IOptions<T> per module with ValidateDataAnnotations + ValidateOnStart
- Dual extension methods (services + middleware) for explicit pipeline control
- Response envelope via opt-in action filter (not global middleware)

### Critical Pitfalls

See [PITFALLS.md](./PITFALLS.md) for all 7 pitfalls with detailed code samples and recovery strategies.

1. **Middleware ordering causes silent failures** -- Rate limiting before routing, auth before routing, compression after static files all fail silently. Prevention: define the canonical middleware skeleton in Program.cs from day one with all `Use*` calls visible (never hidden inside extension methods). Address in Phase 1.
2. **JWT + Identity cookie scheme conflict** -- Identity sets cookie auth as default; API endpoints get 302 redirects instead of 401. Prevention: use a `PolicyScheme` with `ForwardDefaultSelector` that routes Bearer-header requests to JWT and others to cookies. Address in the Auth phase.
3. **EF Core multi-provider migrations are incompatible** -- Migrations generated for SQLite crash on SQL Server and vice versa. Prevention: separate migration assemblies per provider from the first migration. Address in the Data phase.
4. **Serilog two-stage bootstrap misconfiguration** -- Bootstrap logger and hosted logger are separate instances; startup crashes go unlogged. Prevention: use canonical `CreateBootstrapLogger()` + `AddSerilog()` + `Log.CloseAndFlush()` in finally. Address in the Logging phase.
5. **IOptions validation deferred until first access** -- Missing config sections bind silently with null values. Prevention: every module uses `ValidateDataAnnotations().ValidateOnStart()`. Establish as convention in Phase 1.
6. **Module cross-coupling via shared types** -- Modules referencing each other directly defeats removability. Prevention: strict dependency rules enforced by architectural tests (NetArchTest). Establish in Phase 1.
7. **FluentValidation.AspNetCore is deprecated** -- Auto-validation pipeline removed in v12. Prevention: use manual `IValidator<T>` injection with explicit `ValidateAsync()` calls.

## Implications for Roadmap

Based on the combined research, the project naturally decomposes into 5 phases ordered by dependency satisfaction, architectural risk, and the principle that observability should exist before the features it monitors.

### Phase 1: Solution Scaffold and Foundation

**Rationale:** Every module depends on the Host, Shared project, IOptions<T> conventions, and the middleware skeleton. The exception handler must be the first middleware. This phase establishes the architectural rules that prevent the top pitfalls (cross-coupling, middleware ordering, silent config failures).
**Delivers:** Compilable solution structure with Host + Shared projects, Program.cs with grouped middleware skeleton, IOptions<T> base pattern with ValidateOnStart convention, global exception handling (IExceptionHandler + ProblemDetails), and a basic health check endpoint.
**Features addressed:** Global exception handling (table stakes #1), strongly-typed configuration (table stakes #10), health checks skeleton (table stakes #7), grouped Program.cs layout (differentiator #7).
**Pitfalls avoided:** Middleware ordering (#1), IOptions ValidateOnStart (#5), module cross-coupling (#6).
**Stack elements:** .NET 10, ASP.NET Core 10 built-in middleware only. No external packages yet.

### Phase 2: Observability

**Rationale:** Logging must exist before complex modules (Auth, Data) are built so that debugging is available from the start. Serilog's two-stage bootstrap is a known pitfall that should be resolved in isolation.
**Delivers:** Starter.WebApi.Logging module with Serilog two-stage bootstrap, configurable sinks (Console, File, Seq), request logging middleware, and structured log enrichment.
**Features addressed:** Structured logging (table stakes #2).
**Pitfalls avoided:** Serilog two-stage bootstrap misconfiguration (#4).
**Stack elements:** Serilog.AspNetCore 10.0, Serilog.Settings.Configuration 10.0, sink packages.

### Phase 3: Data Layer

**Rationale:** Auth depends on EF Core for Identity stores. The multi-provider migration strategy must be designed before the first migration is created -- retrofitting is expensive. This phase is the foundation for the Auth module.
**Delivers:** Starter.WebApi.Data module with AppDbContext, per-provider migration assemblies (SQLite + SQL Server stubs), provider switching via DatabaseOptions, sample entity with Fluent API configuration, migration helper script.
**Features addressed:** EF Core data access (table stakes #5).
**Pitfalls avoided:** EF Core multi-provider migration incompatibility (#3).
**Stack elements:** Microsoft.EntityFrameworkCore 10.0.5, Microsoft.EntityFrameworkCore.Sqlite 10.0.5, Design + Tools packages.

### Phase 4: Security and API Surface

**Rationale:** Auth is the highest-complexity module and benefits from having Data and Logging already in place. CORS, Swagger/OpenAPI, FluentValidation, and API versioning are grouped here because they collectively define the API's public contract and all benefit from being developed against a running authenticated API.
**Delivers:** Starter.WebApi.Auth module (Identity + Google OAuth + JWT Bearer with PolicyScheme), Starter.WebApi.Api module (API versioning with sample v1/v2 controllers, Scalar/OpenAPI documentation, CORS, FluentValidation with Problem Details integration).
**Features addressed:** Authentication and authorization (table stakes #4), CORS (table stakes #6), Swagger/OpenAPI (table stakes #3), FluentValidation (table stakes #8), API versioning (differentiator #2).
**Pitfalls avoided:** JWT + Identity cookie scheme conflict (#2), FluentValidation.AspNetCore deprecation (#7).
**Stack elements:** Identity.EntityFrameworkCore, JwtBearer, Authentication.Google, Scalar.AspNetCore, Microsoft.AspNetCore.OpenApi, Asp.Versioning.Mvc, FluentValidation 12.1.

### Phase 5: Production Hardening

**Rationale:** Rate limiting, caching, response compression, and the response envelope are independent modules that layer on top of the existing API. They can be built in parallel and each validates the "single-line removal" promise in isolation.
**Delivers:** Rate limiting module (built-in middleware, appsettings-driven policies), Starter.WebApi.Caching module (IMemoryCache + IDistributedCache), response compression (Gzip/Brotli opt-in), standardized response envelope (action filter, not global middleware).
**Features addressed:** Rate limiting (differentiator #3), caching abstraction (differentiator #5), response compression (differentiator #4), response envelope (differentiator #6).
**Pitfalls avoided:** Rate limiter before authentication (#1 sub-case), response compression BREACH risk (documented opt-in).
**Stack elements:** All built-in ASP.NET Core middleware. No external packages.

### Phase 6: Testing and Validation

**Rationale:** Integration tests exercise the full module stack and -- critically -- validate the removability promise by testing that each module can be removed without breaking the build. Unit tests validate individual module services. This phase must come last because it depends on all modules being complete.
**Delivers:** Starter.WebApi.Tests.Unit project, Starter.WebApi.Tests.Integration project with WebApplicationFactory, architectural tests (module isolation via NetArchTest), module removal smoke tests.
**Features addressed:** Testing infrastructure (table stakes #9), module removal verification (core differentiator).
**Pitfalls avoided:** All pitfalls verified via the "Looks Done But Isn't" checklist from PITFALLS.md.
**Stack elements:** xUnit v3, NSubstitute, AwesomeAssertions, Microsoft.AspNetCore.Mvc.Testing.

### Phase Ordering Rationale

- **Dependency-driven:** Shared and Host must exist first. Data before Auth (Identity needs DbContext). Logging before everything complex (debugging requires structured logs).
- **Risk-front-loaded:** The three highest-risk pitfalls (middleware ordering, multi-provider migrations, JWT/Cookie conflict) are addressed in Phases 1, 3, and 4 respectively -- before they can compound.
- **Independence-grouped:** Phase 5 modules are all independently removable and have no cross-dependencies, making them parallelizable.
- **Verification last:** Tests validate the completed system and the removability promise, which can only be tested once all modules exist.

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 4 (Security and API Surface):** Auth is the highest-complexity module. The JWT + Identity + Google OAuth + PolicyScheme interaction is intricate and warrants a focused `/gsd:research-phase` to nail down the exact registration order, token issuance flow, and scheme forwarding behavior.
- **Phase 3 (Data Layer):** The per-provider migration assembly pattern needs concrete implementation research -- the EF Core docs show the concept but the exact `MigrationsAssembly()` configuration and design-time factory setup varies by provider.

**Phases with standard, well-documented patterns (skip research):**
- **Phase 1 (Solution Scaffold):** Extension method composition, IOptions<T>, IExceptionHandler, and ProblemDetails are all thoroughly documented by Microsoft.
- **Phase 2 (Observability):** Serilog's two-stage bootstrap is canonical and well-documented by Nicholas Blumhardt.
- **Phase 5 (Production Hardening):** Rate limiting, caching, compression, and CORS are all built-in middleware with extensive Microsoft documentation.
- **Phase 6 (Testing):** WebApplicationFactory integration testing is a mature, well-established pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All packages verified on NuGet with .NET 10 compatibility. Versions confirmed as of March 2026. First-party packages dominate. |
| Features | HIGH | Feature landscape validated against 7 open-source boilerplates plus Microsoft best-practices docs. Prevalence counts provide empirical backing. |
| Architecture | HIGH | Extension method composition pattern verified across multiple authoritative sources (Microsoft Learn, community libraries). Middleware ordering from official .NET 10 docs. |
| Pitfalls | HIGH | All critical pitfalls verified against Microsoft official documentation or authoritative library maintainer posts (Blumhardt for Serilog, FluentValidation GitHub issues). Recovery strategies tested. |

**Overall confidence:** HIGH

### Gaps to Address

- **Response envelope design decision:** The envelope pattern (wrapping all responses in `ApiResponse<T>`) conflicts slightly with the single-line removal promise if implemented as global middleware. Research recommends an opt-in action filter or attribute, but the exact design needs to be resolved during Phase 5 implementation. Consider whether the envelope adds enough value to justify the coupling.
- **Serilog.Sinks.OpenTelemetry version pinning:** The stack research recommends this sink for Azure Monitor/App Insights forward compatibility, but the exact version and OTLP configuration for App Insights needs validation during Logging module implementation. The classic `Serilog.Sinks.ApplicationInsights` still works as a fallback.
- **Auth module: token refresh flow:** The research covers JWT issuance and validation but does not deeply address refresh token rotation. This is a security-critical concern that should be designed explicitly during Phase 4 planning.
- **Asp.Versioning.Mvc 10.0.0-preview.1:** A preview version exists but 8.1.1 is recommended for stability. Monitor for a stable 10.x release during development that may offer tighter .NET 10 integration.
- **HealthChecks.UI.Client at 9.0.0:** The Xabaril health checks ecosystem has not yet released 10.0.0 packages. They work on .NET 10 but verify continued compatibility as .NET 10 servicing updates ship.

## Sources

### Primary (HIGH confidence)
- [ASP.NET Core 10 What's New -- Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0)
- [ASP.NET Core Middleware Ordering -- Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-10.0)
- [EF Core 10 What's New -- Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-10.0/whatsnew)
- [EF Core Multi-Provider Migrations -- Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/providers)
- [SQLite Provider Limitations -- Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/providers/sqlite/limitations)
- [Options Pattern for Library Authors -- Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/options-library-authors)
- [ASP.NET Core Rate Limiting -- Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit)
- [ASP.NET Core Health Checks -- Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)
- [IExceptionHandler Error Handling -- Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling)
- [Multi-Scheme Authorization -- Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/limitingidentitybyscheme)
- [Bootstrap Logging with Serilog -- Nicholas Blumhardt](https://nblumhardt.com/2020/10/bootstrap-logger/)
- [FluentValidation ASP.NET Core Deprecation -- GitHub #1960](https://github.com/FluentValidation/FluentValidation/issues/1960)

### Secondary (MEDIUM confidence)
- [fullstackhero/dotnet-starter-kit](https://github.com/fullstackhero/dotnet-starter-kit) -- most feature-complete boilerplate analyzed
- [jasontaylordev/CleanArchitecture](https://github.com/jasontaylordev/CleanArchitecture) -- 19.8k stars, ASP.NET Core 10
- [ardalis/CleanArchitecture](https://github.com/ardalis/cleanarchitecture) -- Steve Smith's template
- [Modular Architecture in ASP.NET Core -- codewithmukesh](https://codewithmukesh.com/blog/modular-architecture-in-aspnet-core/)
- [Modular Monoliths -- Thinktecture](https://www.thinktecture.com/en/asp-net-core/modular-monolith/)
- [Global Error Handling -- Milan Jovanovic](https://www.milanjovanovic.tech/blog/global-error-handling-in-aspnetcore-from-middleware-to-modern-handlers)

---
*Research completed: 2026-03-18*
*Ready for roadmap: yes*
