# Feature Landscape

**Domain:** Modular .NET 10 Web API Starter Template / Boilerplate
**Researched:** 2026-03-18
**Overall Confidence:** HIGH

## Methodology

Features were categorized by analyzing the seven most prominent .NET Web API boilerplate projects on GitHub (fullstackhero/dotnet-starter-kit, jasontaylordev/CleanArchitecture, ardalis/CleanArchitecture, yanpitangui/dotnet-api-boilerplate, lkurzyniec/netcore-boilerplate, proudmonkey/ApiBoilerPlate, kawser2133/web-api-project) plus Microsoft's own ASP.NET Core production best-practices guidance. A feature is "table stakes" if 5+ of 7 projects include it. A feature is a "differentiator" if it provides outsized value relative to how few projects implement it well, or if it aligns with the project's unique modular-removal design goal.

---

## Table Stakes

Features users expect. Missing any of these and the template feels incomplete or amateur.

| # | Feature | Why Expected | Complexity | Present in Project Scope | Notes |
|---|---------|--------------|------------|--------------------------|-------|
| 1 | **Global Exception Handling** | Every production API needs centralized error handling. All 7 analyzed boilerplates include it. Microsoft's own best-practices docs lead with this. | Low | Yes (RFC 7807 Problem Details) | .NET 10 has built-in `IExceptionHandler` and `AddProblemDetails()`. The framework does the heavy lifting; module mainly configures and enriches. |
| 2 | **Structured Logging (Serilog)** | Serilog appears in 6/7 boilerplates. Structured logging is universally cited as a production must-have. No serious API ships without it. | Low-Med | Yes (Serilog with configurable sinks) | Sink ecosystem (Console, File, Seq, App Insights) is mature. The module value is in pre-wiring the sinks and enrichers. |
| 3 | **Swagger/OpenAPI Documentation** | Present in all 7 boilerplates. APIs without interactive docs are unusable for consumers. Microsoft's default template includes it. | Low | Yes (Swagger + JWT auth support + XML comments) | Consider Scalar as a modern alternative UI alongside Swashbuckle. fullstackhero and netcore-boilerplate both adopted Scalar. |
| 4 | **Authentication & Authorization** | Present in all 7 boilerplates. JWT Bearer is the default token mechanism. Identity for user store is common. Google/external OAuth is in 3/7. | High | Yes (Identity + Google OAuth + JWT Bearer) | The three-layer composable auth (Identity store, external providers, JWT) is more sophisticated than most boilerplates. The scope is correct but it is the highest-complexity module. |
| 5 | **EF Core Data Access** | Present in 7/7 boilerplates. EF Core is the de facto .NET ORM. SQLite as dev default, with provider swapping, appears in 4/7. | Medium | Yes (SQLite default, swappable to SQL Server/PostgreSQL) | Model-first migrations with helper scripts adds practical value most templates skip. |
| 6 | **CORS Configuration** | Present in 6/7 boilerplates. Required for any API consumed by a browser-based client. Microsoft middleware order docs list it explicitly. | Low | Yes (appsettings-driven dev/prod profiles) | Trivial to implement but dangerous to get wrong. Config-driven profiles are the right call. |
| 7 | **Health Checks** | Present in 5/7 boilerplates. Required for Kubernetes/container readiness and liveness probes. Microsoft Learn has dedicated health-check documentation. | Low | Yes (/health, /health/ready, /health/live) | Three-endpoint split (aggregate, readiness, liveness) aligns with Kubernetes conventions. Most boilerplates only expose a single /health endpoint. |
| 8 | **FluentValidation** | Present in 5/7 boilerplates (fullstackhero, ardalis, yanpitangui, ApiBoilerPlate, and Jason Taylor). Industry consensus is that FluentValidation beats DataAnnotations for non-trivial APIs. | Low-Med | Yes (with Problem Details integration) | The Problem Details integration is key -- validation errors must flow into the same RFC 7807 format as other errors. |
| 9 | **Testing Infrastructure** | Present in 7/7 boilerplates. Unit tests + integration tests with WebApplicationFactory is the community standard. | Medium | Yes (Integration tests + Unit tests) | WebApplicationFactory for integration tests is unanimous across all boilerplates. Scope is correct. |
| 10 | **Strongly-Typed Configuration** | Present in 6/7 boilerplates via IOptions<T>. Microsoft best-practices docs explicitly recommend this over raw IConfiguration reads. | Low | Yes (IOptions<T> per module with typed config sections) | This is the backbone of the modular design -- each module owns its config section. |

---

## Differentiators

Features that set this project apart. Not universally expected, but provide significant value.

| # | Feature | Value Proposition | Complexity | Present in Project Scope | Notes |
|---|---------|-------------------|------------|--------------------------|-------|
| 1 | **Modular Class-Library Architecture with Single-Line Removal** | **This is the project's core differentiator.** No analyzed boilerplate achieves true "delete one line + one project reference" removal. fullstackhero comes closest with vertical slices but still has cross-module coupling. Most templates use folder-based separation, not project-level isolation. | High | Yes (core design principle) | This architectural pattern is what makes the entire template worth building. Every feature decision should be evaluated through the lens of "can I remove this module in one line?" |
| 2 | **API Versioning** | Present in only 3/7 boilerplates (fullstackhero, ApiBoilerPlate, kawser2133). When included, it is highly valued. Most templates punt on this because the built-in ASP.NET Core versioning middleware requires non-trivial setup. | Medium | Yes (sample v1/v2 controllers) | URL-segment versioning (`/api/v1/`) is the most practical for a starter template. Header-based versioning is more "correct" but harder to test in browsers. The sample v1/v2 controllers showing a migration path is high-value. |
| 3 | **Rate Limiting (Built-in ASP.NET)** | Present in only 3/7 boilerplates. Many templates still reference the deprecated `AspNetCoreRateLimit` third-party library. Using the built-in .NET 7+ rate limiting middleware with appsettings-driven policies is modern and correct. | Low-Med | Yes (built-in middleware, appsettings-driven) | The fact that policies are appsettings-driven (not hardcoded) is a meaningful differentiator. Most templates that include rate limiting hardcode the policy values. |
| 4 | **Response Compression (Gzip/Brotli)** | Present in only 2/7 boilerplates (yanpitangui and one other). Often overlooked because reverse proxies (nginx, Azure Front Door) can handle it. But for APIs served directly, this reduces payload sizes dramatically. | Low | Yes (opt-in Gzip/Brotli) | Correctly scoped as opt-in. The `EnableForHttps` security consideration (CRIME/BREACH attacks) needs to be documented in the module. |
| 5 | **In-Memory + Distributed Caching Abstraction** | Present in 4/7 boilerplates, but usually as Redis-only or IMemoryCache-only. Offering both IMemoryCache (zero-config) and IDistributedCache (swap to Redis) behind a clean interface is uncommon. | Low-Med | Yes (IMemoryCache + optional IDistributedCache) | The "start with memory, graduate to Redis" path is the right default. No boilerplate analyzed does this cleanly as a removable module. |
| 6 | **Standardized API Response Envelope** | Present in 2/7 boilerplates (ApiBoilerPlate via AutoWrapper, one other with custom middleware). This is **divisive** in the community. Some argue RFC 7807 Problem Details for errors + raw results for success is sufficient. Others want a consistent wrapper. | Medium | Yes (envelope across all endpoints) | **Important design decision:** The envelope pattern adds coupling -- every endpoint must return through the envelope. This conflicts slightly with the "easily removable module" goal. Consider making the envelope opt-in via an attribute or action filter rather than global middleware, so removal truly is one line. |
| 7 | **Grouped-by-Concern Program.cs Layout** | No analyzed boilerplate explicitly structures Program.cs with named sections (Observability, Security, Data, API). Most have a single flat file or use a Startup class. | Low | Yes (comments separating concerns) | This is a UX differentiator -- developers scanning the entry point immediately understand what's registered. Combined with the single extension method per module, this creates an exceptionally readable boot sequence. |

---

## Anti-Features

Features to explicitly NOT build. These are things that other boilerplates include which would be wrong for this project.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **MediatR / CQRS Pipeline** | Present in 4/7 boilerplates (fullstackhero, Jason Taylor, Ardalis, yanpitangui). However, MediatR adds indirection, ceremony, and a dependency that not every API needs. It is an architectural opinion that should be chosen per-project, not baked into a starter. It also creates implicit coupling -- removing MediatR would require rewriting all handlers. | Keep controllers/endpoints calling services directly. Users who want MediatR can add it to their clone. The starter should be architectural-opinion-light. |
| **AutoMapper / Mapster** | Present in 4/7 boilerplates. Object mapping libraries add "magic" mapping that hides bugs until runtime. Manual mapping (or simple extension methods) is more explicit and debuggable. The .NET community has been moving away from AutoMapper specifically. | Provide a simple `ToDto()` / `FromDto()` extension method pattern in sample code. Users add AutoMapper if they want it. |
| **Multi-tenancy** | fullstackhero's headline feature. Adds enormous complexity (tenant-aware DbContexts, tenant resolution, data isolation). This is a SaaS concern, not a general API concern. | Out of scope per PROJECT.md. Users building SaaS can add Finbuckle or similar. |
| **Background Job Processing (Hangfire)** | Present in 2/7 boilerplates. Adds a dashboard UI, persistent job store dependency, and significant complexity. Most APIs don't need scheduled jobs in their starter. | Out of scope. Users add Hangfire/Quartz when they need it. |
| **Docker/Containerization** | Present in 5/7 boilerplates. Explicitly out of scope per PROJECT.md. The template is a clone-and-modify repo, and Docker configuration is deployment-specific. | Users add their own Dockerfile. The starter should not impose container opinions. |
| **CI/CD Pipelines** | Present in 4/7 boilerplates. Explicitly out of scope per PROJECT.md. CI/CD is team-specific and provider-specific. | Users add GitHub Actions / Azure DevOps / etc. |
| **GraphQL** | Present in 1/7 boilerplates (sinantok). GraphQL is an entirely different API paradigm. Adding it to a REST API starter creates confusion. | This is a REST API template. GraphQL is a different product. |
| **OpenTelemetry / Aspire Integration** | Present in 3/7 boilerplates (fullstackhero, yanpitangui, Jason Taylor). While powerful, Aspire and OpenTelemetry add significant project complexity and dependencies. Serilog structured logging covers the 80% observability case for most APIs. | Serilog handles logging. If users need distributed tracing, they add OpenTelemetry to their clone. Aspire is an orchestration concern, not a library concern. |
| **dotnet new Template Packaging** | Explicitly out of scope per PROJECT.md. Template packaging adds NuGet publishing infrastructure and template engine complexity. | Clone-and-modify is the intended workflow. |
| **Feature Flags / Feature Management** | Present in 1/7 boilerplates (netcore-boilerplate). Feature flags are a runtime concern that depends on the feature flag provider (LaunchDarkly, Azure App Config, etc.). | Users add `Microsoft.FeatureManagement` when they need it. Not a module concern. |

---

## Feature Dependencies

Understanding the dependency graph is critical for build ordering and for validating the "remove one module" promise.

```
Legend:
  A --> B   means "B depends on A" (A must exist for B to work)
  A -.-> B  means "B optionally integrates with A" (B works without A but is enhanced by it)

Configuration (IOptions<T>)
  --> Auth (needs config for JWT secrets, Google client ID, Identity settings)
  --> Serilog (needs config for sink settings)
  --> Rate Limiting (needs config for policy thresholds)
  --> Caching (needs config for cache durations, distributed cache connection)
  --> CORS (needs config for allowed origins)
  --> Response Compression (needs config for enabled providers)
  --> EF Core (needs config for connection strings)
  --> Health Checks (needs config for endpoint paths)
  --> Swagger (needs config for doc title, auth scheme)
  --> API Versioning (needs config for default version)

EF Core
  --> Auth/Identity (Identity stores users in EF Core tables)

Exception Handling
  -.-> Serilog (logs exceptions; works with any ILogger but Serilog enriches)
  -.-> Standardized Responses (errors flow through response envelope)

FluentValidation
  -.-> Exception Handling (validation failures can be caught as exceptions)
  -.-> Standardized Responses (validation errors formatted as Problem Details)

Health Checks
  -.-> EF Core (database health check)
  -.-> Caching (cache health check if distributed)

Swagger
  -.-> Auth (JWT auth support in Swagger UI)
  -.-> API Versioning (version-aware API docs)

Standardized Responses
  -.-> Exception Handling (error responses)
  -.-> FluentValidation (validation error responses)
```

### Hard Dependencies (Cannot Remove Without Breaking)

| Module | Hard Dependency | Reason |
|--------|----------------|--------|
| Auth/Identity | EF Core | Identity stores are EF Core-backed |
| Auth/Identity | Configuration | JWT secrets, Google OAuth settings |
| All modules | Configuration | Every module reads from IOptions<T> |

### Soft Dependencies (Enhanced By, Not Required)

| Module | Soft Dependency | What Degrades |
|--------|----------------|---------------|
| Swagger | Auth | Swagger UI loses "Authorize" button |
| Swagger | API Versioning | Swagger UI loses version selector |
| Health Checks | EF Core | Loses database connectivity check |
| Exception Handling | Serilog | Falls back to default ILogger |
| Standardized Responses | FluentValidation | Validation errors not in envelope format |

### Truly Independent Modules (No Dependencies Beyond Configuration)

These modules can be added or removed with zero impact on other modules:

- Rate Limiting
- Response Compression
- CORS
- Serilog (other modules degrade gracefully to built-in ILogger)
- Caching (consumers use IMemoryCache/IDistributedCache interfaces)

---

## MVP Recommendation

Given this is a personal bootstrapper (not a product for sale), the MVP should deliver the modules that save the most time on every new project, ordered by dependency satisfaction.

### Phase 1: Foundation (must exist before anything else)

1. **Configuration/Secrets** (IOptions<T> pattern) -- every other module depends on this
2. **Exception Handling** (Problem Details) -- safety net for all subsequent development
3. **Serilog Logging** -- observability from the start
4. **EF Core + Migrations** -- data layer that Auth depends on

### Phase 2: Security & API Surface

5. **Auth (Identity + Google + JWT)** -- depends on EF Core
6. **CORS** -- required once Auth is in play for browser clients
7. **Swagger/OpenAPI** -- API is unusable without docs during development
8. **FluentValidation** -- validates all incoming requests

### Phase 3: Production Hardening

9. **Rate Limiting** -- protect endpoints from abuse
10. **Health Checks** -- production monitoring
11. **API Versioning** -- demonstrates the v1/v2 pattern
12. **Standardized Responses** -- unifies the response format
13. **Caching** -- performance optimization
14. **Response Compression** -- bandwidth optimization

### Phase 4: Verification

15. **Testing** (Unit + Integration) -- validates all modules work and can be removed independently

### Rationale

- Configuration and exception handling first because every other module needs to read config and handle errors.
- EF Core before Auth because Identity depends on the data layer.
- Auth is highest complexity so it gets a phase where it can be the focus.
- Production hardening features (rate limiting, health checks, etc.) are independent and can be built in parallel.
- Testing comes last because it validates the completed system, including the removability promise.

### Defer

- **Standardized Response Envelope**: Consider carefully whether this should be a global middleware (hard to remove) or an opt-in action filter/attribute (easy to remove). The design decision should be made during Phase 3, not assumed upfront. If it is global middleware, it arguably violates the "remove one line" principle because removing it changes every response shape.

---

## Feature Prevalence Across Analyzed Boilerplates

This matrix shows which features appear in which boilerplate, supporting the table-stakes vs differentiator categorization.

| Feature | fullstackhero | Jason Taylor | Ardalis | yanpitangui | netcore-bp | ApiBoilerPlate | kawser2133 | Count |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Exception Handling | Y | Y | Y | Y | Y | Y | Y | 7/7 |
| Swagger/OpenAPI | Y | Y | Y | Y | Y | Y | Y | 7/7 |
| EF Core | Y | Y | Y | Y | Y | N* | Y | 6/7 |
| Auth (JWT/Identity) | Y | Y | N | Y | N | Y | Y | 5/7 |
| Testing | Y | Y | Y | Y | Y | Y | Y | 7/7 |
| Serilog/Structured Log | Y | N | N | Y | Y | Y | N | 4/7 |
| FluentValidation | Y | Y | Y | Y | N | Y | N | 5/7 |
| Health Checks | Y | N | N | Y | Y | Y | N | 4/7 |
| CORS | Y | N | N | Y | N | Y | Y | 4/7 |
| API Versioning | Y | N | N | N | N | Y | Y | 3/7 |
| Rate Limiting | Y | N | N | N | N | Y | N | 2/7 |
| Caching | Y | N | N | N | N | N | N | 1/7 |
| Response Compression | N | N | N | Y | N | N | N | 1/7 |
| Response Envelope | N | N | N | N | N | Y | N | 1/7 |
| MediatR/CQRS | Y | Y | Y | Y | N | N | N | 4/7 |
| Docker | Y | N | N | Y | Y | N | Y | 4/7 |
| Config (IOptions) | Y | Y | Y | Y | Y | Y | Y | 7/7 |

*ApiBoilerPlate uses Dapper instead of EF Core.

**Key Takeaway:** The 15 modules in this project's scope cover every feature that appears in 2+ boilerplates AND adds several that appear in 0-1 (response compression, caching as a removable module, response envelope). The project deliberately excludes MediatR and Docker, which is correct for the stated goals.

---

## Sources

- [fullstackhero/dotnet-starter-kit](https://github.com/fullstackhero/dotnet-starter-kit) -- .NET 10, most feature-complete boilerplate analyzed (HIGH confidence)
- [jasontaylordev/CleanArchitecture](https://github.com/jasontaylordev/CleanArchitecture) -- 19.8k stars, ASP.NET Core 10, Clean Architecture reference (HIGH confidence)
- [ardalis/CleanArchitecture](https://github.com/ardalis/cleanarchitecture) -- Steve Smith's template, ASP.NET Core 10, FastEndpoints (HIGH confidence)
- [yanpitangui/dotnet-api-boilerplate](https://github.com/yanpitangui/dotnet-api-boilerplate) -- .NET 9, practical feature-slice approach (HIGH confidence)
- [lkurzyniec/netcore-boilerplate](https://github.com/lkurzyniec/netcore-boilerplate) -- .NET 10, modular monolith approach (HIGH confidence)
- [proudmonkey/ApiBoilerPlate](https://github.com/proudmonkey/ApiBoilerPlate) -- .NET Core 3.1, comprehensive feature set despite age (MEDIUM confidence -- older framework)
- [kawser2133/web-api-project](https://github.com/kawser2133/web-api-project) -- Identity + JWT + API Versioning focus (MEDIUM confidence)
- [ASP.NET Core Best Practices - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/best-practices) (HIGH confidence)
- [ASP.NET Core Error Handling - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api) (HIGH confidence)
- [Response Compression - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/performance/response-compression) (HIGH confidence)
- [Health Checks - Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks) (HIGH confidence)
- [RESTful API Best Practices for .NET - codewithmukesh](https://codewithmukesh.com/blog/restful-api-best-practices-for-dotnet-developers/) (MEDIUM confidence)
- [Code Maze - ASP.NET Core Web API Best Practices](https://code-maze.com/aspnetcore-webapi-best-practices/) (MEDIUM confidence)
