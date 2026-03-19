---
phase: 05-production-hardening
plan: 03
subsystem: infra
tags: [health-checks, asp-net-core, ef-core, liveness, readiness, http-client]

# Dependency graph
requires:
  - phase: 03-data-layer
    provides: AppDbContext for database connectivity health check
provides:
  - Starter.HealthChecks class library module
  - AddAppHealthChecks/UseAppHealthChecks extension methods
  - /health (aggregate), /health/ready (readiness), /health/live (liveness) endpoints
  - ExternalServiceHealthCheck custom IHealthCheck with configurable URI
  - JSON response writer with status, duration, and per-check details
affects: [05-04-program-cs-wiring]

# Tech tracking
tech-stack:
  added: [Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore]
  patterns: [health-check-module, three-endpoint-probe-pattern, custom-IHealthCheck]

key-files:
  created:
    - src/Starter.HealthChecks/Starter.HealthChecks.csproj
    - src/Starter.HealthChecks/Options/HealthCheckModuleOptions.cs
    - src/Starter.HealthChecks/Checks/ExternalServiceHealthCheck.cs
    - src/Starter.HealthChecks/HealthChecksExtensions.cs
  modified:
    - src/Starter.Data/Starter.Data.csproj
    - Starter.WebApi.slnx

key-decisions:
  - "HealthChecks module files were pre-committed by parallel 05-02 executor; Task 2 (InternalsVisibleTo) was the remaining work"

patterns-established:
  - "Health check three-endpoint pattern: /health (aggregate), /health/ready (tagged ready), /health/live (predicate=false)"
  - "Custom IHealthCheck using primary constructor with IHttpClientFactory and IOptions injection"

requirements-completed: [HLTH-01, HLTH-02, HLTH-03, HLTH-04, HLTH-05]

# Metrics
duration: 5min
completed: 2026-03-19
---

# Phase 05 Plan 03: Health Checks Summary

**Health checks module with /health, /health/ready, /health/live endpoints, AddDbContextCheck for database, and custom ExternalServiceHealthCheck**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-19T04:40:40Z
- **Completed:** 2026-03-19T04:46:20Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created Starter.HealthChecks class library with three health check endpoints
- Registered AddDbContextCheck<AppDbContext> with "ready" tag for database connectivity probing
- Built custom ExternalServiceHealthCheck using IHttpClientFactory with configurable URI and timeout
- Added InternalsVisibleTo in Starter.Data for AppDbContext access from HealthChecks module

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Starter.HealthChecks module** - `30c9a24` (feat) -- pre-committed by parallel executor in 05-02 plan
2. **Task 2: Add InternalsVisibleTo for Starter.HealthChecks** - `71cd00a` (feat)

## Files Created/Modified
- `src/Starter.HealthChecks/Starter.HealthChecks.csproj` - Module project with EF Core health check NuGet and Data project reference
- `src/Starter.HealthChecks/Options/HealthCheckModuleOptions.cs` - Config options with ExternalServiceUri and TimeoutSeconds
- `src/Starter.HealthChecks/Checks/ExternalServiceHealthCheck.cs` - Custom IHealthCheck probing external HTTP endpoint
- `src/Starter.HealthChecks/HealthChecksExtensions.cs` - AddAppHealthChecks + UseAppHealthChecks with 3 mapped endpoints and JSON writer
- `src/Starter.Data/Starter.Data.csproj` - Added InternalsVisibleTo for Starter.HealthChecks
- `Starter.WebApi.slnx` - Added Starter.HealthChecks to /Modules/ folder

## Decisions Made
- HealthChecks module files (Task 1) were already committed by a parallel 05-02 executor -- verified files match plan exactly, no re-commit needed
- InternalsVisibleTo was the only remaining modification needed (Task 2)

## Deviations from Plan

None - plan executed exactly as written. Task 1 files were pre-created by a parallel executor but matched plan specifications exactly.

## Issues Encountered
- Private NuGet feed (promineo.pkgs.visualstudio.com) returned 401 -- used --ignore-failed-sources flag for restore (packages available from nuget.org)
- Task 1 files already committed by parallel 05-02 executor -- verified match and skipped redundant commit

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Health checks module ready for Program.cs wiring in Plan 04
- AddAppHealthChecks/UseAppHealthChecks follow established module extension pattern
- Requires appsettings.json HealthChecks section for ExternalServiceUri configuration

## Self-Check: PASSED

- All 4 created files exist on disk
- Commit 30c9a24 (Task 1) found in git log
- Commit 71cd00a (Task 2) found in git log
- InternalsVisibleTo for Starter.HealthChecks present in Starter.Data.csproj
- Starter.HealthChecks present in Starter.WebApi.slnx
- `dotnet build src/Starter.HealthChecks/Starter.HealthChecks.csproj` succeeds with 0 errors

---
*Phase: 05-production-hardening*
*Completed: 2026-03-19*
