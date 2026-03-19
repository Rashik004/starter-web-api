# Phase 4: Security and API Surface - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Add authentication (Identity + Google OAuth + JWT Bearer) as three independently removable auth modules, API versioning with URL segment strategy, OpenAPI/Scalar interactive documentation, CORS configuration, and FluentValidation input validation. Each capability is a separate class library module following the established `AddApp*`/`UseApp*` composition pattern. Collectively these define the public API contract.

</domain>

<decisions>
## Implementation Decisions

### Auth module organization
- Three separate class library projects: `Starter.Auth.Identity`, `Starter.Auth.Jwt`, `Starter.Auth.Google`
- `Starter.Auth.Shared` project holds cross-auth concerns: PolicyScheme configuration, ForwardDefaultSelector logic, auth constants, and the `AppUser` entity
- `AppUser : IdentityUser` lives in `Starter.Auth.Shared/` — both `Starter.Data` (for DbContext) and auth projects reference it
- `AppDbContext` inherits from `IdentityDbContext<AppUser>` (standard ASP.NET Identity approach)
- `Starter.Data` permanently references `Starter.Auth.Shared` + `Microsoft.AspNetCore.Identity.EntityFrameworkCore` — removing auth means removing the 3 auth projects + extension calls, but Data keeps its Auth.Shared reference and Identity table schema (harmless)
- Removing an auth layer = delete that project + its extension method call in Program.cs + its project reference

### Other Phase 4 modules
- `Starter.Cors` — separate class library with `AddAppCors()` extension method
- `Starter.Validation` — separate class library with `AddAppValidation()` for FluentValidation
- `Starter.Versioning` — separate class library with `AddAppVersioning()` for API versioning
- `Starter.OpenApi` — separate class library with `AddAppOpenApi()` / `UseAppOpenApi()` for OpenAPI + Scalar

### Login & token endpoints
- Dedicated `AuthController` in the Host project (`Starter.WebApi/Controllers/AuthController.cs`)
- `POST /api/auth/register` → 201 with `{ userId, email, accessToken, expiresIn }` (auto-login on registration)
- `POST /api/auth/login` → 200 with `{ accessToken, expiresIn }`
- `GET /api/auth/google` → 302 redirect to Google → callback returns `{ accessToken, expiresIn }`
- JWT token lifetime: 60 minutes by default, configurable via `Jwt:ExpirationMinutes` in appsettings.json
- JWT SecretKey managed via User Secrets in development (appsettings.json has empty placeholder with comment pointing to User Secrets setup)
- Authorization: plain `[Authorize]` attribute on protected endpoints — no roles or policies in the starter (code comments show how to add them)

### API versioning
- TodoController moves from `/api/todos` to `/api/v1/todos` (URL segment versioning)
- V2 sample: `TodoV2Controller` at `/api/v2/todos` with expanded DTO adding `priority` (enum), `dueDate` (DateTime?), and `tags` (string?) fields
- V2 expanded fields are added to the `TodoItem` entity in the database (new migration required) — V1 DTO simply doesn't expose them
- Both v1 and v2 endpoints work simultaneously against the same entity

### OpenAPI & Scalar documentation
- Scalar UI visibility is config-driven via `OpenApi:EnableScalar` appsettings flag (not environment check)
- Endpoints grouped by version + controller in Scalar UI (v1 > Todos, v2 > Todos, Auth)
- XML documentation comments demonstrated on sample controllers (TodoController, AuthController) — no build-level enforcement
- JWT Bearer auth integrated in Scalar UI (authorize button)

### Claude's Discretion
- Whether auth endpoints (`/api/auth/*`) are versioned or unversioned — pick what's cleanest
- PolicyScheme behavior when only one auth layer remains (always register PolicyScheme vs simplify to single scheme)
- CORS policy configuration details (which headers, methods, specific origin patterns)
- FluentValidation wiring details (how validators are discovered and registered)
- Exact OpenAPI document configuration (title, description, contact info)
- Middleware ordering for new middleware (CORS, auth, versioning in the pipeline)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project foundation
- `.planning/phases/01-solution-scaffold-and-foundation/01-CONTEXT.md` — Extension method naming (`AddApp*`/`UseApp*`), module naming (`Starter.{Module}`), Program.cs grouped-by-concern layout, internal visibility pattern, IOptions with ValidateOnStart, ProblemDetails error shape with `traceId` + `errors`
- `.planning/phases/02-observability/02-CONTEXT.md` — Logging module as reference for module structure, appsettings section pattern with `Enabled` flags, request logging health check exclusions
- `.planning/phases/03-data-layer/03-CONTEXT.md` — AppDbContext is internal (not sealed), assembly scanning via `ApplyConfigurationsFromAssembly()`, TodoItem entity shape, IRepository<T>/ITodoService contracts in Shared, migration assembly pattern

### Requirements
- `.planning/REQUIREMENTS.md` — AUTH-01..08, CORS-01..03, DOCS-01..04, VERS-01..03, VALD-01..03 define the scope for this phase

### Existing code
- `src/Starter.WebApi/Program.cs` — Composition root with `// --- Security ---` placeholder (line 24) and `// (Phase 4: app.UseAuthentication(), app.UseAuthorization())` middleware slot (line 41)
- `src/Starter.Data/AppDbContext.cs` — Current DbContext that will change to IdentityDbContext<AppUser> base class
- `src/Starter.Shared/Exceptions/` — Existing exception types including UnauthorizedException, ForbiddenException
- `src/Starter.ExceptionHandling/` — Reference module pattern for extension methods and project structure
- `src/Starter.Data/Entities/` — TodoItem entity that gets expanded with v2 fields

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Starter.Shared/Exceptions/UnauthorizedException.cs` and `ForbiddenException.cs` — Auth module should throw these for GlobalExceptionHandler integration (401, 403 responses)
- `Starter.ExceptionHandling/ExceptionHandlingExtensions.cs` — Reference pattern for `AddApp*`/`UseApp*` extension methods
- `Starter.Logging/LoggingExtensions.cs` — Reference pattern for `WebApplicationBuilder` extensions and IOptions configuration
- `Starter.Data/DataExtensions.cs` — Reference pattern for both `AddApp*` (services) and `UseApp*` (middleware) extension methods

### Established Patterns
- IOptions<T> with ValidateDataAnnotations and ValidateOnStart — all new modules must follow this
- `internal` visibility by default; only extension methods and contracts are `public`
- Module config sections in appsettings.json with JSON comments explaining configuration
- Extension methods on `WebApplicationBuilder` (not just `IServiceCollection`) when builder-level access is needed

### Integration Points
- `Program.cs` line 24: `// --- Security ---` placeholder for auth extension calls
- `Program.cs` line 41: `// (Phase 4: app.UseAuthentication(), app.UseAuthorization())` middleware slot
- `Program.cs` line 30: `builder.Services.AddControllers()` — versioning attaches here
- `Starter.Data/AppDbContext.cs` — base class changes from `DbContext` to `IdentityDbContext<AppUser>`
- `Starter.Data.csproj` — needs new project reference to `Starter.Auth.Shared` and NuGet reference to `Microsoft.AspNetCore.Identity.EntityFrameworkCore`
- `appsettings.json` — needs Jwt, Cors, OpenApi, and Validation config sections
- Solution file — needs 7 new projects: Auth.Shared, Auth.Identity, Auth.Jwt, Auth.Google, Cors, Validation, Versioning, OpenApi (8 total)

</code_context>

<specifics>
## Specific Ideas

- The auth removal story should be simple: delete the project, delete the extension method call, delete the project reference — done. No DbContext changes needed for removing individual auth layers.
- Registration auto-returns a JWT so the client can start making authenticated calls immediately — one round-trip, not two.
- V2 TodoController demonstrates the most common real-world versioning scenario: same entity, expanded response contract. Both versions work simultaneously.
- Scalar UI visibility is config-driven (not environment-based) so internal APIs can expose docs in staging/production if desired.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-security-and-api-surface*
*Context gathered: 2026-03-18*
