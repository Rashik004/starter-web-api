---
phase: 04-security-and-api-surface
plan: 01
subsystem: auth
tags: [identity, aspnet-identity, ef-core, policy-scheme, jwt-options, migration]

# Dependency graph
requires:
  - phase: 03-data-layer
    provides: AppDbContext with DbContext base class, TodoItem entity, EF Core infrastructure
provides:
  - Starter.Auth.Shared project with AppUser entity, AuthConstants, JwtOptions, PolicyScheme extension
  - IdentityDbContext<AppUser> base class on AppDbContext
  - TodoItem v2 fields (Priority, DueDate, Tags) and TodoItemV2Dto
  - SQLite migration for Identity tables and TodoItem v2 columns
affects: [04-02, 04-03, 04-04, 04-05, 04-06]

# Tech tracking
tech-stack:
  added: [Microsoft.AspNetCore.Identity.EntityFrameworkCore 10.0.5]
  patterns: [PolicyScheme with ForwardDefaultSelector, IdentityDbContext inheritance, options-pattern for JWT config]

key-files:
  created:
    - src/Starter.Auth.Shared/Starter.Auth.Shared.csproj
    - src/Starter.Auth.Shared/Entities/AppUser.cs
    - src/Starter.Auth.Shared/Constants/AuthConstants.cs
    - src/Starter.Auth.Shared/Options/JwtOptions.cs
    - src/Starter.Auth.Shared/AuthSharedExtensions.cs
    - src/Starter.Data.Migrations.Sqlite/Migrations/20260318170037_AddIdentityAndTodoV2.cs
  modified:
    - src/Starter.Data/Starter.Data.csproj
    - src/Starter.Data/AppDbContext.cs
    - src/Starter.Data/Entities/TodoItem.cs
    - src/Starter.Data/Configuration/TodoItemConfiguration.cs
    - src/Starter.Shared/Contracts/ITodoService.cs
    - Starter.WebApi.slnx
    - src/Starter.WebApi/Starter.WebApi.csproj

key-decisions:
  - "Used AuthConstants.JwtScheme instead of JwtBearerDefaults.AuthenticationScheme to avoid JwtBearer package dependency in Auth.Shared"
  - "TodoPriority enum defined as internal in same file as TodoItem entity for cohesion"

patterns-established:
  - "Auth shared library pattern: cross-cutting auth types (entities, constants, options) in Starter.Auth.Shared referenced by both Data and auth layer projects"
  - "PolicyScheme ForwardDefaultSelector pattern: routes Bearer header to JWT scheme, falls back to Identity cookie scheme"

requirements-completed: [AUTH-01, AUTH-04, AUTH-05, AUTH-06, AUTH-07]

# Metrics
duration: 6min
completed: 2026-03-18
---

# Phase 4 Plan 1: Auth Shared Foundation Summary

**Auth.Shared library with AppUser IdentityUser entity, PolicyScheme routing, JWT options, and IdentityDbContext migration for ASP.NET Identity tables**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-18T16:55:57Z
- **Completed:** 2026-03-18T17:01:51Z
- **Tasks:** 3
- **Files modified:** 13

## Accomplishments
- Created Starter.Auth.Shared project with AppUser entity, AuthConstants, JwtOptions, and PolicyScheme extension method
- Modified AppDbContext to inherit from IdentityDbContext<AppUser> enabling full ASP.NET Identity table support
- Expanded TodoItem entity with v2 fields (Priority, DueDate, Tags) and added TodoItemV2Dto for versioned API support
- Generated SQLite migration capturing all 7 Identity tables and 3 new TodoItem columns without destructive changes

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Starter.Auth.Shared project** - `a98d544` (feat)
2. **Task 2: Modify Data layer for IdentityDbContext and TodoItem v2** - `2aa239f` (feat)
3. **Task 3: Generate SQLite migration** - `f931111` (feat)

## Files Created/Modified
- `src/Starter.Auth.Shared/Starter.Auth.Shared.csproj` - Auth shared class library project
- `src/Starter.Auth.Shared/Entities/AppUser.cs` - IdentityUser subclass for the application
- `src/Starter.Auth.Shared/Constants/AuthConstants.cs` - Scheme name constants (PolicyScheme, JWT, Identity, Google)
- `src/Starter.Auth.Shared/Options/JwtOptions.cs` - Validated JWT configuration binding
- `src/Starter.Auth.Shared/AuthSharedExtensions.cs` - PolicyScheme with ForwardDefaultSelector registration
- `src/Starter.Data/AppDbContext.cs` - Changed base from DbContext to IdentityDbContext<AppUser>
- `src/Starter.Data/Entities/TodoItem.cs` - Added Priority, DueDate, Tags v2 fields and TodoPriority enum
- `src/Starter.Data/Configuration/TodoItemConfiguration.cs` - V2 column configuration with defaults
- `src/Starter.Shared/Contracts/ITodoService.cs` - Added TodoItemV2Dto record
- `src/Starter.Data.Migrations.Sqlite/Migrations/20260318170037_AddIdentityAndTodoV2.cs` - Identity + v2 migration

## Decisions Made
- Used AuthConstants.JwtScheme ("Bearer") instead of JwtBearerDefaults.AuthenticationScheme to avoid adding Microsoft.AspNetCore.Authentication.JwtBearer package dependency to Auth.Shared (the constant value is identical)
- TodoPriority enum defined as internal in the same file as TodoItem entity for cohesion and encapsulation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced JwtBearerDefaults with AuthConstants.JwtScheme**
- **Found during:** Task 1 (Auth.Shared project creation)
- **Issue:** JwtBearerDefaults.AuthenticationScheme requires Microsoft.AspNetCore.Authentication.JwtBearer package which is not in the shared meta-package; build error CS0234
- **Fix:** Used AuthConstants.JwtScheme constant (already defined as "Bearer") instead of JwtBearerDefaults.AuthenticationScheme
- **Files modified:** src/Starter.Auth.Shared/AuthSharedExtensions.cs
- **Verification:** dotnet build succeeds with 0 errors
- **Committed in:** a98d544 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minimal - used existing constant with identical value. No scope creep.

## Issues Encountered
- File lock on DLLs from a running Starter.WebApi process (PID 36908) during Task 2 build verification; process had already terminated by the time kill was attempted, rebuild succeeded

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Auth foundation complete with AppUser, AuthConstants, JwtOptions, and PolicyScheme
- Ready for Plan 04-02+ to implement Identity registration/login, JWT token generation, and Google OAuth
- IdentityDbContext migration provides all Identity tables needed for user management
- TodoItem v2 fields ready for versioned API controllers

## Self-Check: PASSED

All 9 key files verified present. All 3 task commits verified in git log.

---
*Phase: 04-security-and-api-surface*
*Completed: 2026-03-18*
