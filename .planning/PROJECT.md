# Starter.WebApi

## What This Is

A modular, production-ready .NET 10 Web API starter repository for personal use. Each feature is a self-contained class library registered via a single extension method call in `Program.cs`. To add or remove a feature, add/remove the corresponding line and project reference. Designed to be cloned and customized as the foundation for new API projects.

## Core Value

Every module is independently removable — deleting one extension method call and its project reference cleanly removes that feature with no cascading breakage.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Extension method composition pattern with grouped-by-concern Program.cs
- [ ] ASP.NET Identity + Google OAuth + JWT Bearer auth (all enabled by default, each independently removable)
- [ ] Structured logging via Serilog with configurable sinks (Console, File, App Insights, Seq)
- [ ] Rate limiting using built-in ASP.NET middleware with appsettings-driven policies
- [ ] In-memory caching with IMemoryCache and optional IDistributedCache
- [ ] Global exception handling middleware returning RFC 7807 Problem Details
- [ ] EF Core database with SQLite default, swappable to SQL Server/PostgreSQL
- [ ] Model-first migrations with helper scripts
- [ ] Health check endpoints (/health, /health/ready, /health/live)
- [ ] CORS configuration via appsettings with dev/prod profiles
- [ ] Swagger/OpenAPI with JWT auth support and XML comments
- [ ] API versioning with sample v1/v2 controllers
- [ ] FluentValidation with Problem Details integration
- [ ] Standardized API response envelope across all endpoints
- [ ] Gzip/Brotli response compression (opt-in)
- [ ] IOptions<T> pattern per module with strongly-typed config sections
- [ ] Integration test project with WebApplicationFactory
- [ ] Unit test project with sample service-layer tests

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
| Class libraries per module | Stronger boundaries than folders, lighter than NuGet packages | — Pending |
| .NET 10 | Latest framework for a fresh starter | — Pending |
| Starter repo over dotnet new template | Less ceremony, faster to iterate for personal use | — Pending |
| SQLite as dev default | Zero-config friction for local development | — Pending |
| Serilog as logging pipeline | Industry standard, sink ecosystem, structured by default | — Pending |
| Identity + Google + JWT all enabled by default | Demonstrates full auth composition; remove what you don't need | — Pending |
| Grouped-by-concern Program.cs | Scannable at a glance, clear section ownership | — Pending |
| FluentValidation over DataAnnotations | More expressive, testable, separates validation from models | — Pending |

---
*Last updated: 2026-03-18 after initialization*
