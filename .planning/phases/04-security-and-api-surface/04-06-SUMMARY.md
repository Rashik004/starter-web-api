---
phase: 04-security-and-api-surface
plan: 06
subsystem: api
tags: [program-cs, composition-root, wiring, appsettings, xml-docs, integration]

# Dependency graph
requires:
  - phase: 04-security-and-api-surface (plans 01-05)
    provides: All Phase 4 modules (Auth.Shared, Auth.Identity, Auth.Jwt, Auth.Google, Versioning, Cors, Validation, OpenApi, controllers)
provides:
  - Complete composition root in Program.cs with all Phase 4 modules wired
  - appsettings.json with Jwt, Cors, OpenApi, and Authentication:Google config sections
  - XML documentation generation enabled for Scalar/OpenAPI
  - End-to-end auth flow (register, login, JWT, protected endpoints)
  - Working versioned API (v1, v2) with validation and Scalar docs
affects: [phase-5-production-hardening, phase-6-testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Composition root groups services by concern (Observability, Security, Data, API)"
    - "Middleware pipeline follows canonical order (ExceptionHandler, HTTPS, Logging, Data, CORS, Auth, AuthZ, OpenApi, Controllers)"
    - "AddIdentityCore instead of AddIdentity to preserve PolicyScheme ForwardDefaultSelector"

key-files:
  created: []
  modified:
    - src/Starter.WebApi/Program.cs
    - src/Starter.WebApi/Starter.WebApi.csproj
    - src/Starter.WebApi/appsettings.json
    - src/Starter.WebApi/appsettings.Development.json
    - src/Starter.Auth.Identity/IdentityExtensions.cs
    - src/Starter.Auth.Shared/AuthSharedExtensions.cs
    - .gitignore

key-decisions:
  - "Used AddIdentityCore instead of AddIdentity to prevent Identity from overriding PolicyScheme ForwardDefaultSelector with its own cookie defaults"
  - "Development JWT SecretKey is a non-production placeholder so app starts without User Secrets setup"
  - "No Google credentials in appsettings.Development.json -- empty strings trigger safe no-op in AddAppGoogle()"
  - "XML doc warnings (1591) suppressed globally to avoid noise from undocumented internal types"

patterns-established:
  - "PolicyScheme compatibility: use AddIdentityCore (not AddIdentity) when PolicyScheme with ForwardDefaultSelector is the auth coordination layer"
  - "Config-driven feature gating: Google OAuth handler only registers when credentials are present"

requirements-completed: [AUTH-08, DOCS-04]

# Metrics
duration: 8min
completed: 2026-03-18
---

# Phase 4 Plan 06: Program.cs Wiring Summary

**All Phase 4 modules wired into Program.cs composition root with correct middleware ordering, appsettings.json configured, and end-to-end auth flow verified (register, login, JWT, v1/v2 endpoints, Scalar UI)**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-18T17:20:00Z
- **Completed:** 2026-03-18T17:28:00Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Program.cs wired with all Phase 4 module extension methods in correct grouped-by-concern order (Observability, Security, Data, API)
- Middleware pipeline follows canonical order: ExceptionHandler, HTTPS, Logging, Data, CORS, Auth, AuthZ, OpenApi, Controllers
- appsettings.json contains Jwt, Cors, OpenApi, and Authentication:Google config sections with documentation comments
- End-to-end auth flow verified: register returns 201 with JWT, login returns 200 with JWT, protected endpoints require Bearer token
- API versioning verified: v1 and v2 todo endpoints respond correctly with different DTOs
- FluentValidation verified: invalid registration data returns 422 ProblemDetails
- Scalar UI loads at /scalar/v1 with JWT authorize button

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire Program.cs with all Phase 4 modules and update appsettings.json** - `81f3593` (feat)
2. **Auth fix: use AddIdentityCore to preserve PolicyScheme auth defaults** - `56092c6` (fix)
3. **Task 2: Verify application starts and endpoints respond** - checkpoint:human-verify (approved, no separate commit)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `src/Starter.WebApi/Program.cs` - Composition root with all Phase 4 module extension method calls
- `src/Starter.WebApi/Starter.WebApi.csproj` - XML documentation generation enabled (GenerateDocumentationFile + NoWarn 1591)
- `src/Starter.WebApi/appsettings.json` - Jwt, Cors, OpenApi, Authentication:Google config sections added
- `src/Starter.WebApi/appsettings.Development.json` - Dev JWT secret and permissive CORS override
- `src/Starter.Auth.Identity/IdentityExtensions.cs` - Changed AddIdentity to AddIdentityCore for PolicyScheme compatibility
- `src/Starter.Auth.Shared/AuthSharedExtensions.cs` - Simplified ForwardDefaultSelector after AddIdentityCore fix
- `.gitignore` - Added XML documentation file patterns

## Decisions Made
- **AddIdentityCore over AddIdentity:** AddIdentity registers its own cookie authentication defaults that override the PolicyScheme's ForwardDefaultSelector, breaking JWT Bearer auth on protected endpoints. AddIdentityCore registers Identity services (UserManager, SignInManager, stores) without touching the authentication scheme configuration, preserving our PolicyScheme as the coordination layer.
- **Dev JWT secret as placeholder:** appsettings.Development.json includes a non-production JWT SecretKey so the app starts in development without requiring User Secrets setup. Production guidance via comments directs to User Secrets or Azure Key Vault.
- **No Google credentials in Development config:** Empty strings in base appsettings.json cause AddAppGoogle() to skip handler registration (safe no-op). Developers opt-in via User Secrets when they want Google OAuth.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AddIdentity overrides PolicyScheme ForwardDefaultSelector**
- **Found during:** Task 2 (human verification -- GET /api/v1/todos with Bearer token returned 401)
- **Issue:** AddIdentity registers IdentityConstants.ApplicationScheme as the default authentication scheme, overriding the PolicyScheme's ForwardDefaultSelector. This caused JWT Bearer tokens to be ignored in favor of cookie authentication, resulting in 401 on all protected endpoints.
- **Fix:** Changed AddIdentity to AddIdentityCore in IdentityExtensions.cs. AddIdentityCore registers Identity services (UserManager, SignInManager, EF Core stores) without touching authentication scheme defaults. Also simplified ForwardDefaultSelector in AuthSharedExtensions.cs.
- **Files modified:** src/Starter.Auth.Identity/IdentityExtensions.cs, src/Starter.Auth.Shared/AuthSharedExtensions.cs
- **Verification:** GET /api/v1/todos with Bearer token now returns 200
- **Committed in:** `56092c6`

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Essential fix for auth correctness. AddIdentity's side effects are a known ASP.NET Core pitfall when combining Identity with custom authentication schemes. No scope creep.

## Issues Encountered
- The AddIdentity vs AddIdentityCore distinction is a subtle ASP.NET Core behavior. AddIdentity is designed for MVC apps with cookie-based auth and registers its own default schemes. When using a PolicyScheme to coordinate multiple authentication schemes (JWT + cookies), AddIdentityCore must be used instead to avoid scheme override conflicts.

## User Setup Required

External services require manual configuration:
- **JWT Secret Key:** `dotnet user-secrets set "Jwt:SecretKey" "your-256-bit-secret-key-here-min-32-chars"` (development has a placeholder; production requires a real key via environment variables or Azure Key Vault)
- **Google OAuth (optional):** `dotnet user-secrets set "Authentication:Google:ClientId" "your-client-id"` and `dotnet user-secrets set "Authentication:Google:ClientSecret" "your-secret"` from Google Cloud Console

## Next Phase Readiness
- Phase 4 is fully complete -- all 6 plans executed
- Application builds, starts, and all endpoints respond correctly
- Auth flow works end-to-end: register -> JWT -> access protected endpoint
- Ready for Phase 5: Production Hardening (rate limiting, caching, compression, health checks)
- No blockers or concerns for Phase 5

## Self-Check: PASSED

All 7 modified files verified present. Both task commits (81f3593, 56092c6) verified in git log.

---
*Phase: 04-security-and-api-surface*
*Completed: 2026-03-18*
