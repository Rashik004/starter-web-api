# Roadmap: Starter.WebApi

## Overview

This roadmap delivers a modular .NET 10 Web API starter repository where every feature is a self-contained class library removable with a single extension method call deletion. The phases follow dependency order: scaffold the solution structure and foundational patterns first, then add observability so debugging exists before complex modules, build the data layer that auth depends on, layer security and the API public contract together, harden with independent production modules, and finally validate everything with tests that prove the removability promise.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Solution Scaffold and Foundation** - Host + Shared projects, extension method composition pattern, IOptions conventions, grouped Program.cs, and global exception handling
- [x] **Phase 2: Observability** - Serilog structured logging module with two-stage bootstrap and configurable sinks (completed 2026-03-18)
- [x] **Phase 3: Data Layer** - EF Core module with SQLite default, multi-provider migration assemblies, and provider switching (completed 2026-03-18)
- [ ] **Phase 4: Security and API Surface** - Auth module (Identity + Google OAuth + JWT Bearer), API versioning, OpenAPI/Scalar docs, CORS, and FluentValidation
- [ ] **Phase 5: Production Hardening** - Rate limiting, caching, response compression, standardized response envelope, and health check endpoints
- [ ] **Phase 6: Testing and Validation** - Integration tests, unit tests, architectural tests, and module removal smoke tests

## Phase Details

### Phase 1: Solution Scaffold and Foundation
**Goal**: Developers can clone the repo and see a compilable, runnable solution that demonstrates the modular extension method composition pattern with proper error handling and configuration validation
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, CONF-01, CONF-02, CONF-03, EXCP-01, EXCP-02, EXCP-03, EXCP-04, EXCP-05
**Success Criteria** (what must be TRUE):
  1. Solution compiles and runs with Host + Shared projects; Program.cs has grouped-by-concern layout with Observability, Security, Data, and API sections
  2. A sample module exists as a separate class library exposing AddStarter/UseStarter extension methods, and removing its call + project reference causes no build errors
  3. Misconfigured appsettings.json sections cause immediate startup failure (ValidateOnStart), not silent null bindings
  4. Unhandled exceptions return RFC 7807 Problem Details with stack traces in Development and without in Production
  5. No module class library directly references another module -- only Shared is referenced, and all public surface is limited to extension methods and contracts
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md -- Scaffold solution structure (Host + Shared + ExceptionHandling projects), exception types, extension method composition pattern, IOptions with ValidateOnStart, grouped Program.cs
- [x] 01-02-PLAN.md -- Implement GlobalExceptionHandler with typed exception mapping and RFC 7807 ProblemDetails, create DiagnosticsController for verification

### Phase 2: Observability
**Goal**: All application activity is captured through structured logging with configurable sinks, so that debugging is available before complex modules are built
**Depends on**: Phase 1
**Requirements**: LOG-01, LOG-02, LOG-03, LOG-04, LOG-05, LOG-06
**Success Criteria** (what must be TRUE):
  1. Application startup and shutdown are logged even if the host crashes during initialization (two-stage bootstrap)
  2. Console sink outputs structured log entries in Development; enabling File, Seq, or OpenTelemetry sinks requires only appsettings.json changes with zero code modifications
  3. The Logging module is a separate class library removable by deleting its extension method call and project reference without breaking the solution
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md -- Create Starter.Logging module with SinkRegistrar (Enabled flag pattern), RequestLoggingConfiguration (health check exclusion, dynamic log levels), CorrelationIdMiddleware, and AddAppLogging/UseAppRequestLogging extension methods
- [x] 02-02-PLAN.md -- Wire Program.cs with two-stage bootstrap (try/catch/finally), configure appsettings.json with full Serilog sink configuration, and human-verify structured logging output

### Phase 3: Data Layer
**Goal**: The application has a working EF Core data layer with SQLite for zero-config development and a migration strategy that supports switching to SQL Server or PostgreSQL without regenerating migrations
**Depends on**: Phase 2
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06
**Success Criteria** (what must be TRUE):
  1. Running the application with default configuration creates and uses a SQLite database with no manual setup
  2. Switching the database provider to SQL Server or PostgreSQL requires only an appsettings.json change (connection string and provider name)
  3. Separate migration assemblies exist per provider so that SQLite migrations and SQL Server migrations do not conflict
  4. A sample entity with repository/service layer demonstrates the data access pattern end-to-end (CRUD via API or in-memory test)
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md -- Create Starter.Data module with EF Core 10 multi-provider support (SQLite/SqlServer/PostgreSQL), AppDbContext, DatabaseOptions, TodoItem entity, 3 migration assembly projects with markers, and IRepository<T>/ITodoService contracts in Shared
- [x] 03-02-PLAN.md -- Implement EfRepository<T> and TodoService, create TodoController with CRUD endpoints and DTOs, wire AddAppData/UseAppData into Program.cs, configure appsettings.json Database section
- [x] 03-03-PLAN.md -- Create migration helper scripts (bash + PowerShell), upgrade dotnet-ef tool, generate initial SQLite migration with seed data, and human-verify end-to-end CRUD

### Phase 4: Security and API Surface
**Goal**: The API has a complete authentication system with three independently removable auth layers, versioned endpoints, interactive documentation, input validation, and CORS -- collectively defining the public API contract
**Depends on**: Phase 3
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, AUTH-08, CORS-01, CORS-02, CORS-03, DOCS-01, DOCS-02, DOCS-03, DOCS-04, VERS-01, VERS-02, VERS-03, VALD-01, VALD-02, VALD-03
**Success Criteria** (what must be TRUE):
  1. A user can register, log in with email/password via Identity, and access a protected endpoint using a JWT Bearer token
  2. Google OAuth login is available and returns a JWT; removing the Google OAuth extension method call does not break JWT-only or Identity-only auth
  3. Removing the Identity extension method (JWT-only mode) or removing the JWT extension method (cookie-only mode) each produce a working application with no build errors
  4. API endpoints are accessible at /api/v1/ and /api/v2/ with sample controllers demonstrating the versioning pattern
  5. Scalar UI is available at a documentation endpoint with JWT authorize button, and XML doc comments are visible in the API documentation
  6. Invalid request payloads return RFC 7807 Problem Details responses consistent with the exception handling format
  7. CORS policies differ between Development (permissive) and Production (restrictive), configured entirely via appsettings.json
**Plans**: 6 plans

Plans:
- [ ] 04-01-PLAN.md -- Create Starter.Auth.Shared (AppUser, AuthConstants, JwtOptions, PolicyScheme), modify Data layer to IdentityDbContext<AppUser>, expand TodoItem with v2 fields, generate SQLite migration
- [ ] 04-02-PLAN.md -- Create Starter.Versioning (URL segment versioning), Starter.Cors (config-driven CORS policies), and Starter.Validation (FluentValidation 12 manual injection)
- [ ] 04-03-PLAN.md -- Create Starter.Auth.Identity (ASP.NET Identity with EF Core stores), Starter.Auth.Jwt (JWT Bearer + JwtTokenService), and Starter.Auth.Google (Google OAuth handler)
- [ ] 04-04-PLAN.md -- Create Starter.OpenApi (OpenAPI 3.1 per-version documents, Scalar UI with config-driven visibility, Bearer security scheme transformer)
- [ ] 04-05-PLAN.md -- Create AuthController (register/login/Google OAuth), version TodoController (v1), create TodoV2Controller (v2), add FluentValidation validators
- [ ] 04-06-PLAN.md -- Wire all Phase 4 modules into Program.cs, configure appsettings.json, enable XML docs, and human-verify end-to-end auth flow

### Phase 5: Production Hardening
**Goal**: The API has production-grade rate limiting, caching, response compression, a standardized response envelope, and comprehensive health check endpoints -- all independently removable
**Depends on**: Phase 4
**Requirements**: RATE-01, RATE-02, RATE-03, RATE-04, CACH-01, CACH-02, CACH-03, COMP-01, COMP-02, COMP-03, RESP-01, RESP-02, RESP-03, HLTH-01, HLTH-02, HLTH-03, HLTH-04, HLTH-05
**Success Criteria** (what must be TRUE):
  1. Exceeding rate limits returns 429 Too Many Requests; fixed window, sliding window, and token bucket policies are configurable via appsettings.json with both global and per-endpoint examples
  2. A sample endpoint demonstrates cache-aside pattern with IMemoryCache; switching to IDistributedCache (Redis-backed) requires only configuration changes
  3. Response compression (Gzip/Brotli) is available but disabled by default; enabling it requires one extension method call, and HTTPS compression risks are documented
  4. All endpoints return a consistent response envelope format; the envelope is opt-in via attribute/filter and removing the response module does not affect other endpoints
  5. /health, /health/ready, and /health/live return appropriate status; database connectivity is checked; a sample custom health check for external dependencies is included
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD
- [ ] 05-03: TBD

### Phase 6: Testing and Validation
**Goal**: The starter repo has comprehensive test coverage that validates module functionality and -- critically -- proves the core differentiator: any module can be removed without breaking the build
**Depends on**: Phase 5
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07
**Success Criteria** (what must be TRUE):
  1. Integration tests using WebApplicationFactory exercise health check endpoints, auth flows, and a CRUD operation against the running application
  2. Unit tests validate sample service-layer logic in isolation using NSubstitute for dependencies
  3. Architectural tests (NetArchTest) fail the build if any module class library directly references another module
  4. Module removal smoke tests prove that removing any single module (deleting extension method call + project reference) results in a successful build
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Solution Scaffold and Foundation | 2/2 | Complete | 2026-03-18 |
| 2. Observability | 2/2 | Complete   | 2026-03-18 |
| 3. Data Layer | 3/3 | Complete   | 2026-03-18 |
| 4. Security and API Surface | 0/6 | Not started | - |
| 5. Production Hardening | 0/? | Not started | - |
| 6. Testing and Validation | 0/? | Not started | - |
