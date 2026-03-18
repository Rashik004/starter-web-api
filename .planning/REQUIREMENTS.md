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

- [ ] **EXCP-01**: Global exception handling catches all unhandled exceptions
- [ ] **EXCP-02**: All error responses use RFC 7807 Problem Details format
- [ ] **EXCP-03**: Stack traces are included in Development, hidden in Production
- [ ] **EXCP-04**: Exceptions are logged through the structured logging pipeline
- [ ] **EXCP-05**: Uses built-in IExceptionHandler (not custom middleware)

### Logging

- [ ] **LOG-01**: Serilog is the logging pipeline with two-stage bootstrap pattern
- [ ] **LOG-02**: Console sink is always on in Development
- [ ] **LOG-03**: File sink is configurable via appsettings.json
- [ ] **LOG-04**: Azure Application Insights sink available via Serilog.Sinks.OpenTelemetry
- [ ] **LOG-05**: Seq sink is configurable for local structured log viewing
- [ ] **LOG-06**: Sink configuration is entirely driven by appsettings.json -- no code changes to enable/disable sinks

### Authentication & Authorization

- [ ] **AUTH-01**: ASP.NET Identity provides user/role/claim store backed by EF Core
- [ ] **AUTH-02**: JWT Bearer tokens can be issued and validated for API access
- [ ] **AUTH-03**: Google OAuth is available as an external authentication provider
- [ ] **AUTH-04**: PolicyScheme with ForwardDefaultSelector correctly routes JWT vs cookie authentication
- [ ] **AUTH-05**: Identity store is independently removable (API can work with JWT-only)
- [ ] **AUTH-06**: Google OAuth is independently removable
- [ ] **AUTH-07**: JWT Bearer is independently removable (for server-rendered scenarios)
- [ ] **AUTH-08**: All three auth layers are enabled by default to demonstrate composition

### Database

- [ ] **DATA-01**: EF Core 10 is configured with SQLite as the zero-config development default
- [ ] **DATA-02**: SQL Server provider is available and swappable via configuration
- [ ] **DATA-03**: PostgreSQL provider is available and swappable via configuration
- [ ] **DATA-04**: Separate migration assemblies exist per database provider
- [ ] **DATA-05**: Migration helper scripts are provided (dotnet ef migrations add / database update)
- [ ] **DATA-06**: A repository pattern or thin service layer wraps DbContext

### Health Checks

- [ ] **HLTH-01**: /health endpoint returns aggregate health status
- [ ] **HLTH-02**: /health/ready endpoint returns readiness status
- [ ] **HLTH-03**: /health/live endpoint returns liveness status
- [ ] **HLTH-04**: Database connectivity health check is included
- [ ] **HLTH-05**: A sample custom health check for external dependencies is included

### CORS

- [ ] **CORS-01**: CORS policies are configurable via appsettings.json
- [ ] **CORS-02**: Development profile is permissive (allow all origins)
- [ ] **CORS-03**: Production profile is restrictive (explicit allowed origins)

### API Documentation

- [ ] **DOCS-01**: OpenAPI 3.1 document is generated via Microsoft.AspNetCore.OpenApi
- [ ] **DOCS-02**: Scalar provides the interactive API documentation UI
- [ ] **DOCS-03**: JWT Bearer auth is integrated (authorize button in Scalar UI)
- [ ] **DOCS-04**: XML comment documentation is wired up and visible in API docs

### API Versioning

- [ ] **VERS-01**: API versioning is configured using Asp.Versioning.Http/Mvc
- [ ] **VERS-02**: URL segment versioning is the default strategy (/api/v1/)
- [ ] **VERS-03**: Sample v1 and v2 controllers demonstrate the versioning pattern and migration path

### Input Validation

- [ ] **VALD-01**: FluentValidation 12 is integrated using manual IValidator<T> injection (not deprecated auto-pipeline)
- [ ] **VALD-02**: Validation failures return RFC 7807 Problem Details responses consistent with exception handling
- [ ] **VALD-03**: Sample validators for request DTOs are included

### Standardized Responses

- [ ] **RESP-01**: Consistent response format across all endpoints
- [ ] **RESP-02**: Shared error shape for validation errors, not-found, unauthorized, and unhandled exceptions
- [ ] **RESP-03**: Response envelope is opt-in via attribute or action filter (not global middleware) to preserve module removability

### Rate Limiting

- [ ] **RATE-01**: Built-in System.Threading.RateLimiting / Microsoft.AspNetCore.RateLimiting middleware is used
- [ ] **RATE-02**: Fixed window, sliding window, and token bucket policies are provided as defaults
- [ ] **RATE-03**: Policy configuration is driven by appsettings.json
- [ ] **RATE-04**: Both global and per-endpoint rate limiting policies are demonstrated

### Caching

- [ ] **CACH-01**: IMemoryCache is registered with configurable expiration defaults
- [ ] **CACH-02**: A sample cache-aside pattern is demonstrated in a service layer
- [ ] **CACH-03**: IDistributedCache is available with in-memory default, swappable to Redis

### Response Compression

- [ ] **COMP-01**: Gzip and Brotli response compression middleware is available
- [ ] **COMP-02**: Module is opt-in, disabled by default
- [ ] **COMP-03**: HTTPS compression security considerations (CRIME/BREACH) are documented

### Testing

- [ ] **TEST-01**: Integration test project uses WebApplicationFactory<Program>
- [ ] **TEST-02**: Sample tests cover health check endpoints
- [ ] **TEST-03**: Sample tests cover auth flows
- [ ] **TEST-04**: Sample tests cover a CRUD operation
- [ ] **TEST-05**: Unit test project includes sample service-layer tests
- [ ] **TEST-06**: Architectural tests (NetArchTest) enforce no module-to-module references
- [ ] **TEST-07**: Module removal smoke tests prove removing any module doesn't break the build

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
| EXCP-01 | Phase 1 | Pending |
| EXCP-02 | Phase 1 | Pending |
| EXCP-03 | Phase 1 | Pending |
| EXCP-04 | Phase 1 | Pending |
| EXCP-05 | Phase 1 | Pending |
| LOG-01 | Phase 2 | Pending |
| LOG-02 | Phase 2 | Pending |
| LOG-03 | Phase 2 | Pending |
| LOG-04 | Phase 2 | Pending |
| LOG-05 | Phase 2 | Pending |
| LOG-06 | Phase 2 | Pending |
| DATA-01 | Phase 3 | Pending |
| DATA-02 | Phase 3 | Pending |
| DATA-03 | Phase 3 | Pending |
| DATA-04 | Phase 3 | Pending |
| DATA-05 | Phase 3 | Pending |
| DATA-06 | Phase 3 | Pending |
| AUTH-01 | Phase 4 | Pending |
| AUTH-02 | Phase 4 | Pending |
| AUTH-03 | Phase 4 | Pending |
| AUTH-04 | Phase 4 | Pending |
| AUTH-05 | Phase 4 | Pending |
| AUTH-06 | Phase 4 | Pending |
| AUTH-07 | Phase 4 | Pending |
| AUTH-08 | Phase 4 | Pending |
| CORS-01 | Phase 4 | Pending |
| CORS-02 | Phase 4 | Pending |
| CORS-03 | Phase 4 | Pending |
| DOCS-01 | Phase 4 | Pending |
| DOCS-02 | Phase 4 | Pending |
| DOCS-03 | Phase 4 | Pending |
| DOCS-04 | Phase 4 | Pending |
| VERS-01 | Phase 4 | Pending |
| VERS-02 | Phase 4 | Pending |
| VERS-03 | Phase 4 | Pending |
| VALD-01 | Phase 4 | Pending |
| VALD-02 | Phase 4 | Pending |
| VALD-03 | Phase 4 | Pending |
| RATE-01 | Phase 5 | Pending |
| RATE-02 | Phase 5 | Pending |
| RATE-03 | Phase 5 | Pending |
| RATE-04 | Phase 5 | Pending |
| CACH-01 | Phase 5 | Pending |
| CACH-02 | Phase 5 | Pending |
| CACH-03 | Phase 5 | Pending |
| COMP-01 | Phase 5 | Pending |
| COMP-02 | Phase 5 | Pending |
| COMP-03 | Phase 5 | Pending |
| RESP-01 | Phase 5 | Pending |
| RESP-02 | Phase 5 | Pending |
| RESP-03 | Phase 5 | Pending |
| HLTH-01 | Phase 5 | Pending |
| HLTH-02 | Phase 5 | Pending |
| HLTH-03 | Phase 5 | Pending |
| HLTH-04 | Phase 5 | Pending |
| HLTH-05 | Phase 5 | Pending |
| TEST-01 | Phase 6 | Pending |
| TEST-02 | Phase 6 | Pending |
| TEST-03 | Phase 6 | Pending |
| TEST-04 | Phase 6 | Pending |
| TEST-05 | Phase 6 | Pending |
| TEST-06 | Phase 6 | Pending |
| TEST-07 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 73 total
- Mapped to phases: 73
- Unmapped: 0

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after roadmap creation*
