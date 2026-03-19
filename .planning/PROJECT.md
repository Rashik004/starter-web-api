# Starter.WebApi

## What This Is

A modular, production-ready .NET 10 Web API starter repository for personal use. Each feature is a self-contained class library registered via a single extension method call in `Program.cs`. To add or remove a feature, add/remove the corresponding line and project reference. Designed to be cloned and customized as the foundation for new API projects.

## Core Value

Every module is independently removable — deleting one extension method call and its project reference cleanly removes that feature with no cascading breakage.

## Requirements

### Validated

- [x] Extension method composition pattern with grouped-by-concern Program.cs — Validated in Phase 1: Solution Scaffold
- [x] Structured logging via Serilog with configurable sinks (Console, File, App Insights, Seq) — Validated in Phase 2: Observability
- [x] Global exception handling middleware returning RFC 7807 Problem Details — Validated in Phase 2: Observability
- [x] EF Core database with SQLite default, swappable to SQL Server/PostgreSQL — Validated in Phase 3: Data Layer
- [x] Model-first migrations with helper scripts — Validated in Phase 3: Data Layer
- [x] CORS configuration via appsettings with dev/prod profiles — Validated in Phase 4: Security & API Surface
- [x] ASP.NET Identity + Google OAuth + JWT Bearer auth (all enabled by default, each independently removable) — Validated in Phase 4: Security & API Surface
- [x] Swagger/OpenAPI with JWT auth support and XML comments — Validated in Phase 4: Security & API Surface
- [x] API versioning with sample v1/v2 controllers — Validated in Phase 4: Security & API Surface
- [x] FluentValidation with Problem Details integration — Validated in Phase 4: Security & API Surface
- [x] Rate limiting using built-in ASP.NET middleware with appsettings-driven policies — Validated in Phase 5: Production Hardening
- [x] In-memory caching with IMemoryCache and optional IDistributedCache — Validated in Phase 5: Production Hardening
- [x] Health check endpoints (/health, /health/ready, /health/live) — Validated in Phase 5: Production Hardening
- [x] Standardized API response envelope across all endpoints — Validated in Phase 5: Production Hardening
- [x] Gzip/Brotli response compression (opt-in) — Validated in Phase 5: Production Hardening
- [x] IOptions<T> pattern per module with strongly-typed config sections — Validated in Phase 5: Production Hardening
- [x] Integration test project with WebApplicationFactory — Validated in Phase 6: Testing and Validation
- [x] Unit test project with sample service-layer tests — Validated in Phase 6: Testing and Validation
- [x] Architecture tests enforcing module isolation via NetArchTest — Validated in Phase 6: Testing and Validation
- [x] Module removal smoke tests proving any module can be removed without breaking the build — Validated in Phase 6: Testing and Validation

### Active

(None — all requirements validated)

### Out of Scope

- dotnet new template packaging — this is a clone-and-modify starter repo
- NuGet package publishing — modules are class libraries within the solution, not published packages
- Frontend/UI — API only
- CI/CD pipeline — user adds their own
- Docker/containerization — user adds their own
- Azure deployment configuration — user adds their own

## Context

- Personal bootstrapper: optimized for fast project kickoff, not for teaching or onboarding others
- Each module lives in its own class library project (e.g., `Starter.WebApi.Auth`, `Starter.WebApi.Logging`)
- The host Web API project references only the modules it needs
- All module configuration lives in `appsettings.json` under module-owned sections
- Program.cs uses grouped-by-concern style with comments separating Observability, Security, Data, and API sections
- Auth is three composable layers: Identity store (optional) x External providers (Google, extensible) x JWT Bearer (optional)
- SQLite is the zero-config dev default; SQL Server and PostgreSQL are production swap targets
- Solution namespace root: `Starter.WebApi`

## Constraints

- **Runtime**: .NET 10 — latest framework, all packages must target net10.0
- **IDE**: Visual Studio — solution structure must be VS-friendly (.sln, .csproj)
- **Packaging**: Class libraries within solution — no NuGet publishing infrastructure needed
- **Config**: All runtime behavior configurable via appsettings.json / IOptions<T> — no hardcoded values

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Class libraries per module | Stronger boundaries than folders, lighter than NuGet packages | ✓ Good — NetArchTest + 19-module smoke tests prove isolation |
| .NET 10 | Latest framework for a fresh starter | ✓ Good — all packages available, no compatibility issues |
| Starter repo over dotnet new template | Less ceremony, faster to iterate for personal use | ✓ Good — clone-and-modify workflow confirmed |
| SQLite as dev default | Zero-config friction for local development | ✓ Good — auto-migrate on startup, no setup |
| Serilog as logging pipeline | Industry standard, sink ecosystem, structured by default | ✓ Good — two-stage bootstrap catches startup crashes |
| Identity + Google + JWT all enabled by default | Demonstrates full auth composition; remove what you don't need | ✓ Good — smoke tests prove each is independently removable |
| Grouped-by-concern Program.cs | Scannable at a glance, clear section ownership | ✓ Good — 5 sections (Observability, Security, Data, API, Middleware) |
| FluentValidation over DataAnnotations | More expressive, testable, separates validation from models | ✓ Good — manual injection avoids deprecated auto-pipeline |
| AddIdentityCore over AddIdentity | Prevents Identity from overriding PolicyScheme cookie defaults | ✓ Good — discovered during Phase 4 integration |
| Internal by default, public extension methods only | Module boundary enforcement via visibility | ✓ Good — InternalsVisibleTo used only for test + cross-module EF access |
| Separate migration assemblies per provider | SQLite/SqlServer/PostgreSQL migrations don't conflict | ✓ Good — string constants avoid circular references |
| ApiResponseFilter as opt-in ServiceFilter | Preserves module removability; not global middleware | ✓ Good — WrapResponseAttribute provides clean public API |

---
*Last updated: 2026-03-19 after v1.0 milestone completion — all 73 requirements validated, shipped*
