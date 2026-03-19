---
phase: 04-security-and-api-surface
plan: 03
subsystem: auth
tags: [aspnet-identity, jwt, jwtbearer, google-oauth, token-generation, authentication-modules]

# Dependency graph
requires:
  - phase: 04-security-and-api-surface
    plan: 01
    provides: Auth.Shared with AppUser entity, AuthConstants, JwtOptions, PolicyScheme, IdentityDbContext
provides:
  - Starter.Auth.Identity module with ASP.NET Identity registration and EF Core stores
  - Starter.Auth.Jwt module with JwtBearer validation and JwtTokenService for token generation
  - Starter.Auth.Google module with optional Google OAuth handler (conditional on credentials)
affects: [04-04, 04-05, 04-06]

# Tech tracking
tech-stack:
  added: [Microsoft.AspNetCore.Authentication.JwtBearer 10.0.5, Microsoft.AspNetCore.Authentication.Google 10.0.5]
  patterns: [AddApp* extension method per auth layer, conditional handler registration for optional providers, options-pattern with ValidateOnStart for required config]

key-files:
  created:
    - src/Starter.Auth.Identity/Starter.Auth.Identity.csproj
    - src/Starter.Auth.Identity/IdentityExtensions.cs
    - src/Starter.Auth.Jwt/Starter.Auth.Jwt.csproj
    - src/Starter.Auth.Jwt/Services/JwtTokenService.cs
    - src/Starter.Auth.Jwt/JwtExtensions.cs
    - src/Starter.Auth.Google/Starter.Auth.Google.csproj
    - src/Starter.Auth.Google/Options/GoogleAuthOptions.cs
    - src/Starter.Auth.Google/GoogleExtensions.cs
  modified:
    - src/Starter.Data/Starter.Data.csproj
    - Starter.WebApi.slnx
    - src/Starter.WebApi/Starter.WebApi.csproj

key-decisions:
  - "No additional NuGet packages needed for Auth.Identity -- Identity.EntityFrameworkCore comes transitively from Auth.Shared"
  - "JwtTokenService registered as scoped (not singleton) to safely resolve IOptions per request"
  - "GoogleAuthOptions has no [Required] attributes and no ValidateOnStart -- empty credentials are valid and trigger safe no-op"

patterns-established:
  - "Auth layer module pattern: each auth layer is a separate class library with single AddApp* extension method, depends only on Auth.Shared, independently removable"
  - "Optional provider pattern: conditional handler registration based on configuration presence -- app starts without optional provider credentials"

requirements-completed: [AUTH-02, AUTH-03, AUTH-05, AUTH-06, AUTH-07, AUTH-08]

# Metrics
duration: 3min
completed: 2026-03-18
---

# Phase 4 Plan 3: Auth Layer Modules Summary

**Three auth layer class libraries -- Identity with EF Core stores, JWT Bearer validation with JwtTokenService, and conditional Google OAuth -- each independently removable via AddApp* extension pattern**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-18T17:05:42Z
- **Completed:** 2026-03-18T17:09:01Z
- **Tasks:** 3
- **Files modified:** 11

## Accomplishments
- Created Starter.Auth.Identity module registering ASP.NET Identity with AppUser and EF Core stores, with password policy and lockout configuration
- Created Starter.Auth.Jwt module with JwtBearer token validation (HmacSha256, 1-min clock skew) and JwtTokenService generating access tokens with Sub, Email, and Jti claims
- Created Starter.Auth.Google module that conditionally registers Google OAuth handler only when both ClientId and ClientSecret are configured, ensuring app starts without Google credentials

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Starter.Auth.Identity module** - `a1ac671` (feat)
2. **Task 2: Create Starter.Auth.Jwt module** - `ff2fd13` (feat)
3. **Task 3: Create Starter.Auth.Google module** - `136412d` (feat)

## Files Created/Modified
- `src/Starter.Auth.Identity/Starter.Auth.Identity.csproj` - Identity class library with Auth.Shared and Data project references
- `src/Starter.Auth.Identity/IdentityExtensions.cs` - AddAppIdentity registering Identity with AppUser, IdentityRole, EF Core stores, and default token providers
- `src/Starter.Auth.Jwt/Starter.Auth.Jwt.csproj` - JWT class library with JwtBearer NuGet package
- `src/Starter.Auth.Jwt/Services/JwtTokenService.cs` - Public sealed service generating JWT tokens with SymmetricSecurityKey
- `src/Starter.Auth.Jwt/JwtExtensions.cs` - AddAppJwt registering Bearer validation, options binding with ValidateOnStart, and JwtTokenService DI
- `src/Starter.Auth.Google/Starter.Auth.Google.csproj` - Google OAuth class library with Google authentication NuGet package
- `src/Starter.Auth.Google/Options/GoogleAuthOptions.cs` - Configuration class with IsConfigured helper, no [Required] attributes
- `src/Starter.Auth.Google/GoogleExtensions.cs` - AddAppGoogle with conditional handler registration when credentials are present
- `src/Starter.Data/Starter.Data.csproj` - Added InternalsVisibleTo for Auth.Identity to access internal AppDbContext
- `Starter.WebApi.slnx` - Added three auth module projects to /Modules/ solution folder
- `src/Starter.WebApi/Starter.WebApi.csproj` - Added project references for Auth.Identity, Auth.Jwt, Auth.Google

## Decisions Made
- No additional NuGet packages needed for Auth.Identity since Microsoft.AspNetCore.Identity.EntityFrameworkCore comes transitively from Auth.Shared project reference
- JwtTokenService registered as scoped (not singleton) to safely resolve IOptions<JwtOptions> per request scope
- GoogleAuthOptions intentionally has no [Required] data annotations and no ValidateOnStart -- empty credentials are a valid configuration state representing "Google login not enabled"

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Full solution build (`dotnet build Starter.WebApi.slnx`) fails due to pre-existing build errors in Starter.OpenApi project (CS0234/CS0246 for Microsoft.OpenApi.Models namespace). This is not caused by auth module changes -- all three auth projects build independently with 0 errors. The OpenApi issue is from plan 04-02 and is out of scope for this plan.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three auth layers complete and compilable, ready for Plan 04-04+ to wire extension calls in Program.cs
- JwtTokenService is public and scoped, ready for AuthController to inject for login/register token generation
- Google OAuth callback path set to /api/auth/google-callback, ready for AuthController endpoint
- Each module is independently removable by deleting its AddApp* call and project reference

## Self-Check: PASSED

All 8 created files verified present. All 3 task commits verified in git log.

---
*Phase: 04-security-and-api-surface*
*Completed: 2026-03-18*
