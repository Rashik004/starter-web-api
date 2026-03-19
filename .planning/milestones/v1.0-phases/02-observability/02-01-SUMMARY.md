---
phase: 02-observability
plan: 01
subsystem: observability
tags: [serilog, structured-logging, correlation-id, request-logging, opentelemetry, seq]

# Dependency graph
requires:
  - phase: 01-scaffold
    provides: "Extension method composition pattern (AddApp*/UseApp*), solution structure with /Modules/ folder, GlobalExceptionHandler TraceIdentifier usage"
provides:
  - "Starter.Logging class library with 8 Serilog NuGet packages"
  - "SinkRegistrar with Enabled-flag pattern for Console, File, Seq, OpenTelemetry sinks"
  - "AddAppLogging extension method with hybrid config (ReadFrom.Configuration + custom sinks)"
  - "UseAppRequestLogging extension method with health check exclusion and dynamic log levels"
  - "CorrelationIdMiddleware syncing X-Correlation-Id header to TraceIdentifier"
  - "RequestLoggingConfiguration with individually toggleable per-request enrichment"
affects: [02-02-PLAN, program-cs-integration, all-future-modules]

# Tech tracking
tech-stack:
  added: [Serilog.AspNetCore 10.0.0, Serilog.Settings.Configuration 10.0.0, Serilog.Sinks.Console 6.1.1, Serilog.Sinks.File 7.0.0, Serilog.Sinks.Seq 9.0.0, Serilog.Sinks.OpenTelemetry 4.2.0, Serilog.Enrichers.Environment 3.0.1, Serilog.Enrichers.ClientInfo 2.9.0]
  patterns: [custom-sink-enabled-flag-pattern, hybrid-serilog-configuration, health-check-log-exclusion, correlation-id-traceidentifier-sync]

key-files:
  created:
    - src/Starter.Logging/Starter.Logging.csproj
    - src/Starter.Logging/LoggingExtensions.cs
    - src/Starter.Logging/Configuration/SinkRegistrar.cs
    - src/Starter.Logging/Configuration/RequestLoggingConfiguration.cs
    - src/Starter.Logging/Middleware/CorrelationIdMiddleware.cs
  modified:
    - Starter.WebApi.slnx
    - src/Starter.WebApi/Starter.WebApi.csproj

key-decisions:
  - "Omitted Starter.Shared ProjectReference from Starter.Logging since no shared types are used"
  - "Used GetValue<bool?> with null-coalescing for request logging toggles to default to true when config section is missing"

patterns-established:
  - "Enabled-flag sink registration: Custom SinkRegistrar reads Serilog:Sinks:{Name}:Enabled from IConfiguration since serilog-settings-configuration does not natively support it"
  - "Hybrid Serilog config: ReadFrom.Configuration for MinimumLevel/Enrichers/Properties, programmatic ConfigureSinks for conditional sink registration"
  - "Health check path exclusion: Return LogEventLevel.Verbose for /health paths to effectively filter them at typical minimum levels"
  - "Correlation ID alignment: Middleware copies X-Correlation-Id header into HttpContext.TraceIdentifier before any logging, so both Serilog and ProblemDetails share the same value"

requirements-completed: [LOG-01, LOG-03, LOG-04, LOG-05, LOG-06]

# Metrics
duration: 6min
completed: 2026-03-18
---

# Phase 2 Plan 01: Starter.Logging Module Summary

**Serilog structured logging module with custom Enabled-flag sink registration, health check exclusion, dynamic log levels, and correlation ID alignment with ProblemDetails**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-18T12:08:48Z
- **Completed:** 2026-03-18T12:15:21Z
- **Tasks:** 3/3
- **Files modified:** 7

## Accomplishments
- Created Starter.Logging class library with all 8 Serilog NuGet packages, wired into solution under /Modules/
- Implemented SinkRegistrar with custom Enabled-flag pattern for all 4 sinks (Console, File, Seq, OpenTelemetry) since serilog-settings-configuration does not natively support conditional enable/disable
- Built AddAppLogging with hybrid configuration: ReadFrom.Configuration handles MinimumLevel/Enrichers/Properties while ConfigureSinks handles conditional sink registration
- Implemented UseAppRequestLogging with health check path exclusion, dynamic log levels by HTTP status (500+=Error, 400+=Warning, rest=Information), and individually toggleable per-request enrichment (ClientIp, UserAgent, ContentType)
- Created CorrelationIdMiddleware that syncs X-Correlation-Id header into HttpContext.TraceIdentifier for ProblemDetails alignment

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Starter.Logging project with NuGet packages and wire into solution** - `8341c7f` (feat)
2. **Task 2: Implement SinkRegistrar and LoggingExtensions.AddAppLogging()** - `d056112` (feat)
3. **Task 3: Implement RequestLoggingConfiguration, CorrelationIdMiddleware, and complete UseAppRequestLogging** - `6541121` (feat)

## Files Created/Modified
- `src/Starter.Logging/Starter.Logging.csproj` - Class library with 8 Serilog NuGet packages (net10.0)
- `src/Starter.Logging/LoggingExtensions.cs` - Public AddAppLogging and UseAppRequestLogging extension methods
- `src/Starter.Logging/Configuration/SinkRegistrar.cs` - Custom sink registration with Enabled flag per sink from IConfiguration
- `src/Starter.Logging/Configuration/RequestLoggingConfiguration.cs` - GetLevel (health exclusion + dynamic levels), EnrichDiagnosticContext (toggleable properties), MessageTemplate
- `src/Starter.Logging/Middleware/CorrelationIdMiddleware.cs` - Copies X-Correlation-Id header into HttpContext.TraceIdentifier
- `Starter.WebApi.slnx` - Added Starter.Logging under /Modules/ folder
- `src/Starter.WebApi/Starter.WebApi.csproj` - Added ProjectReference to Starter.Logging

## Decisions Made
- **Omitted Starter.Shared reference:** Starter.Logging uses no shared types, so the ProjectReference was omitted per the "no unnecessary references" principle noted in the plan
- **Used nullable bool for config toggles:** EnrichDiagnosticContext uses `GetValue<bool?>` with `?? true` so enrichment defaults to enabled when the config section is entirely missing, rather than silently disabling all enrichment

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Private NuGet source (PromineoCommonComponents) returned 401 during package install. Worked around by specifying `--source https://api.nuget.org/v3/index.json` explicitly. This is a pre-existing environment configuration issue, not related to the plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Starter.Logging module is complete and compilable, ready for Program.cs integration in Plan 02-02
- Plan 02-02 will wire the two-stage bootstrap (try/catch/finally), configure appsettings.json with full Serilog configuration, and human-verify structured logging output
- AddAppLogging and UseAppRequestLogging extension methods follow the same pattern as ExceptionHandling

## Self-Check: PASSED

All 6 created files verified on disk. All 3 task commits (8341c7f, d056112, 6541121) verified in git history.

---
*Phase: 02-observability*
*Completed: 2026-03-18*
