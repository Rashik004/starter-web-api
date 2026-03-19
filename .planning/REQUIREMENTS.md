# Requirements: Starter.WebApi

**Defined:** 2026-03-18
**Core Value:** Every module is independently removable -- deleting one extension method call and its project reference cleanly removes that feature with no cascading breakage.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [x] **FOUND-01**: Solution contains a Shared class library with only contracts (response envelope, config constants, cross-module interfaces)
- [x] **FOUND-02**: Solution contains a Host Web API project that references only the modules it needs
- [x] **FOUND-03**: Each module is a separate class library exposing `AddStarter{Module}` on IServiceCollection and optionally `UseStarter{Module}` on WebApplication
- [x] **FOUND-04**: Program.cs uses grouped-by-concern layout (Observability, Security, Data, API sections) with one extension method call per module
- [x] **FOUND-05**: Removing a module requires only deleting the extension method call(s) in Program.cs and the project reference -- no other changes
- [x] **FOUND-06**: No module references another module directly -- all cross-module communication flows through interfaces in Shared resolved via DI
- [x] **FOUND-07**: All class library projects use `internal` visibility by default; only extension methods and contracts are public

### Configuration

- [x] **CONF-01**: Each module owns a strongly-typed config section in appsettings.json via IOptions<T>
- [x] **CONF-02**: All IOptions<T> registrations use ValidateDataAnnotations and ValidateOnStart to catch misconfiguration at startup
- [x] **CONF-03**: Guidance for User Secrets (development), Environment Variables, and Azure Key Vault (production) is documented

### Exception Handling

- [x] **EXCP-01**: Global exception handling catches all unhandled exceptions
- [x] **EXCP-02**: All error responses use RFC 7807 Problem Details format
- [x] **EXCP-03**: Stack traces are included in Development, hidden in Production
- [x] **EXCP-04**: Exceptions are logged through the structured logging pipeline
- [x] **EXCP-05**: Uses built-in IExceptionHandler (not custom middleware)

### Logging

- [x] **LOG-01**: Serilog is the logging pipeline with two-stage bootstrap pattern
- [x] **LOG-02**: Console sink is always on in Development
- [x] **LOG-03**: File sink is configurable via appsettings.json
- [x] **LOG-04**: Azure Application Insights sink available via Serilog.Sinks.OpenTelemetry
- [x] **LOG-05**: Seq sink is configurable for local structured log viewing
- [x] **LOG-06**: Sink configuration is entirely driven by appsettings.json -- no code changes to enable/disable sinks

### Authentication & Authorization

- [x] **AUTH-01**: ASP.NET Identity provides user/role/claim store backed by EF Core
- [x] **AUTH-02**: JWT Bearer tokens can be issued and validated for API access
- [x] **AUTH-03**: Google OAuth is available as an external authentication provider
- [x] **AUTH-04**: PolicyScheme with ForwardDefaultSelector correctly routes JWT vs cookie authentication
- [x] **AUTH-05**: Identity store is independently removable (API can work with JWT-only)
- [x] **AUTH-06**: Google OAuth is independently removable
- [x] **AUTH-07**: JWT Bearer is independently removable (for server-rendered scenarios)
- [x] **AUTH-08**: All three auth layers are enabled by default to demonstrate composition

### Database

- [x] **DATA-01**: EF Core 10 is configured with SQLite as the zero-config development default
- [x] **DATA-02**: SQL Server provider is available and swappable via configuration
- [x] **DATA-03**: PostgreSQL provider is available and swappable via configuration
- [x] **DATA-04**: Separate migration assemblies exist per database provider
- [x] **DATA-05**: Migration helper scripts are provided (dotnet ef migrations add / database update)
- [x] **DATA-06**: A repository pattern or thin service layer wraps DbContext

### Health Checks

- [x] **HLTH-01**: /health endpoint returns aggregate health status
- [x] **HLTH-02**: /health/ready endpoint returns readiness status
- [x] **HLTH-03**: /health/live endpoint returns liveness status
- [x] **HLTH-04**: Database connectivity health check is included
- [x] **HLTH-05**: A sample custom health check for external dependencies is included

### CORS

- [x] **CORS-01**: CORS policies are configurable via appsettings.json
- [x] **CORS-02**: Development profile is permissive (allow all origins)
- [x] **CORS-03**: Production profile is restrictive (explicit allowed origins)

### API Documentation

- [x] **DOCS-01**: OpenAPI 3.1 document is generated via Microsoft.AspNetCore.OpenApi
- [x] **DOCS-02**: Scalar provides the interactive API documentation UI
- [x] **DOCS-03**: JWT Bearer auth is integrated (authorize button in Scalar UI)
- [x] **DOCS-04**: XML comment documentation is wired up and visible in API docs

### API Versioning

- [x] **VERS-01**: API versioning is configured using Asp.Versioning.Http/Mvc
- [x] **VERS-02**: URL segment versioning is the default strategy (/api/v1/)
- [x] **VERS-03**: Sample v1 and v2 controllers demonstrate the versioning pattern and migration path

### Input Validation

- [x] **VALD-01**: FluentValidation 12 is integrated using manual IValidator<T> injection (not deprecated auto-pipeline)
- [x] **VALD-02**: Validation failures return RFC 7807 Problem Details responses consistent with exception handling
- [x] **VALD-03**: Sample validators for request DTOs are included

### Standardized Responses

- [x] **RESP-01**: Consistent response format across all endpoints
- [x] **RESP-02**: Shared error shape for validation errors, not-found, unauthorized, and unhandled exceptions
- [x] **RESP-03**: Response envelope is opt-in via attribute or action filter (not global middleware) to preserve module removability

### Rate Limiting

- [x] **RATE-01**: Built-in System.Threading.RateLimiting / Microsoft.AspNetCore.RateLimiting middleware is used
- [x] **RATE-02**: Fixed window, sliding window, and token bucket policies are provided as defaults
- [x] **RATE-03**: Policy configuration is driven by appsettings.json
- [x] **RATE-04**: Both global and per-endpoint rate limiting policies are demonstrated

### Caching

- [x] **CACH-01**: IMemoryCache is registered with configurable expiration defaults
- [x] **CACH-02**: A sample cache-aside pattern is demonstrated in a service layer
- [x] **CACH-03**: IDistributedCache is available with in-memory default, swappable to Redis

### Response Compression

- [x] **COMP-01**: Gzip and Brotli response compression middleware is available
- [x] **COMP-02**: Module is opt-in, disabled by default
- [x] **COMP-03**: HTTPS compression security considerations (CRIME/BREACH) are documented

### Testing

- [x] **TEST-01**: Integration test project uses WebApplicationFactory<Program>
- [x] **TEST-02**: Sample tests cover health check endpoints
- [x] **TEST-03**: Sample tests cover auth flows
- [x] **TEST-04**: Sample tests cover a CRUD operation
- [x] **TEST-05**: Unit test project includes sample service-layer tests
- [x] **TEST-06**: Architectural tests (NetArchTest) enforce no module-to-module references
- [x] **TEST-07**: Module removal smoke tests prove removing any module doesn't break the build

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Additional Auth Providers

- **AUTH-V2-01**: Microsoft OAuth external provider
- **AUTH-V2-02**: Refresh token rotation flow

### Observability

- **OBS-V2-01**: OpenTelemetry distributed tracing integration
- **OBS-V2-02**: Aspire orchestration support

### Deployment

- **DEPLOY-V2-01**: Dockerfile and docker-compose
- **DEPLOY-V2-02**: GitHub Actions CI/CD pipeline

## Out of Scope

| Feature | Reason |
|---------|--------|
| MediatR / CQRS | Architectural opinion -- users add if needed |
| AutoMapper / Mapster | Magic mapping hides bugs -- use manual mapping |
| Multi-tenancy | SaaS-specific complexity, not general API concern |
| Background jobs (Hangfire) | Most APIs don't need scheduled jobs in starter |
| GraphQL | Different API paradigm -- this is REST |
| dotnet new template | Clone-and-modify is the intended workflow |
| Feature flags | Provider-specific runtime concern |
| Frontend / UI | API only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete |
| FOUND-06 | Phase 1 | Complete |
| FOUND-07 | Phase 1 | Complete |
| CONF-01 | Phase 1 | Complete |
| CONF-02 | Phase 1 | Complete |
| CONF-03 | Phase 1 | Complete |
| EXCP-01 | Phase 1 | Complete |
| EXCP-02 | Phase 1 | Complete |
| EXCP-03 | Phase 1 | Complete |
| EXCP-04 | Phase 1 | Complete |
| EXCP-05 | Phase 1 | Complete |
| LOG-01 | Phase 2 | Complete |
| LOG-02 | Phase 2 | Complete |
| LOG-03 | Phase 2 | Complete |
| LOG-04 | Phase 2 | Complete |
| LOG-05 | Phase 2 | Complete |
| LOG-06 | Phase 2 | Complete |
| DATA-01 | Phase 3 | Complete |
| DATA-02 | Phase 3 | Complete |
| DATA-03 | Phase 3 | Complete |
| DATA-04 | Phase 3 | Complete |
| DATA-05 | Phase 3 | Complete |
| DATA-06 | Phase 3 | Complete |
| AUTH-01 | Phase 4 | Complete |
| AUTH-02 | Phase 4 | Complete |
| AUTH-03 | Phase 4 | Complete |
| AUTH-04 | Phase 4 | Complete |
| AUTH-05 | Phase 4 | Complete |
| AUTH-06 | Phase 4 | Complete |
| AUTH-07 | Phase 4 | Complete |
| AUTH-08 | Phase 4 | Complete |
| CORS-01 | Phase 4 | Complete |
| CORS-02 | Phase 4 | Complete |
| CORS-03 | Phase 4 | Complete |
| DOCS-01 | Phase 4 | Complete |
| DOCS-02 | Phase 4 | Complete |
| DOCS-03 | Phase 4 | Complete |
| DOCS-04 | Phase 4 | Complete |
| VERS-01 | Phase 4 | Complete |
| VERS-02 | Phase 4 | Complete |
| VERS-03 | Phase 4 | Complete |
| VALD-01 | Phase 4 | Complete |
| VALD-02 | Phase 4 | Complete |
| VALD-03 | Phase 4 | Complete |
| RATE-01 | Phase 5 | Complete |
| RATE-02 | Phase 5 | Complete |
| RATE-03 | Phase 5 | Complete |
| RATE-04 | Phase 5 | Complete |
| CACH-01 | Phase 5 | Complete |
| CACH-02 | Phase 5 | Complete |
| CACH-03 | Phase 5 | Complete |
| COMP-01 | Phase 5 | Complete |
| COMP-02 | Phase 5 | Complete |
| COMP-03 | Phase 5 | Complete |
| RESP-01 | Phase 5 | Complete |
| RESP-02 | Phase 5 | Complete |
| RESP-03 | Phase 5 | Complete |
| HLTH-01 | Phase 5 | Complete |
| HLTH-02 | Phase 5 | Complete |
| HLTH-03 | Phase 5 | Complete |
| HLTH-04 | Phase 5 | Complete |
| HLTH-05 | Phase 5 | Complete |
| TEST-01 | Phase 6 | Complete |
| TEST-02 | Phase 6 | Complete |
| TEST-03 | Phase 6 | Complete |
| TEST-04 | Phase 6 | Complete |
| TEST-05 | Phase 6 | Complete |
| TEST-06 | Phase 6 | Complete |
| TEST-07 | Phase 6 | Complete |

**Coverage:**
- v1 requirements: 73 total
- Mapped to phases: 73
- Unmapped: 0

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after roadmap creation*
