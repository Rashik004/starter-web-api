---
phase: 02-observability
plan: "02"
subsystem: infra
tags: [serilog, structured-logging, aspnet-core, correlation-id, request-logging]

# Dependency graph
requires:
  - phase: 02-01
    provides: Starter.Logging module with AddAppLogging and UseAppRequestLogging extension methods

provides:
  - Two-stage bootstrap logger in Program.cs (captures startup/crash before host initializes)
  - Complete Serilog pipeline wired into ASP.NET Core host via AddAppLogging
  - Request logging middleware mounted via UseAppRequestLogging
  - Full appsettings.json Serilog configuration with 4 configurable sinks (Console enabled, File/Seq/OpenTelemetry disabled)
  - Development-specific log level overrides in appsettings.Development.json

affects: [03-data, 04-security, 05-hardening, 06-testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Two-stage bootstrap pattern: bootstrap logger before host, replaced by full Serilog after AddAppLogging
    - try/catch/finally wrapping entire application for crash capture and Log.CloseAndFlush guarantee
    - Sink enablement via Enabled flags in appsettings.json (zero code changes to toggle sinks)

key-files:
  created: []
  modified:
    - src/Starter.WebApi/Program.cs
    - src/Starter.WebApi/appsettings.json
    - src/Starter.WebApi/appsettings.Development.json

key-decisions:
  - "Bootstrap logger and try/catch/finally live in Program.cs, not inside the Starter.Logging module — they must exist before any module loads and after everything shuts down"
  - "UseAppRequestLogging placed after UseAppExceptionHandling and UseHttpsRedirection per middleware ordering anti-pattern research"
  - "Old Logging section removed from appsettings.json — Serilog replaces the built-in logging pipeline entirely"

patterns-established:
  - "Two-stage bootstrap: Log.Logger = CreateBootstrapLogger() -> try { builder.AddAppLogging() } -> finally { Log.CloseAndFlush() }"
  - "Sink toggle pattern: Serilog:Sinks:{Name}:Enabled controls activation with no code changes required"

requirements-completed: [LOG-01, LOG-02, LOG-06]

# Metrics
duration: 17min
completed: 2026-03-18
---

# Phase 2 Plan 02: Serilog Integration Summary

**Two-stage bootstrap logger wired into Program.cs with complete appsettings.json Serilog configuration covering Console, File, Seq, and OpenTelemetry sinks with Enabled toggles**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-03-18T12:32:00Z
- **Completed:** 2026-03-18T12:49:02Z
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 3

## Accomplishments

- Rewrote Program.cs with two-stage bootstrap: lightweight bootstrap logger captures startup/crash events before the ASP.NET Core host initializes, then AddAppLogging replaces it with the full Serilog pipeline
- Added complete Serilog configuration to appsettings.json with 4 sink sections (Console enabled by default; File, Seq, OpenTelemetry disabled with guidance comments), enricher configuration (FromLogContext, WithEnvironmentName, WithMachineName, WithCorrelationId), and request logging toggles
- Updated appsettings.Development.json with Debug-level overrides for more verbose local development output
- Human-verified the structured logging pipeline end-to-end: bootstrap swap marker visible on startup, structured console output confirmed, HTTP request log lines with status-code-driven log levels working

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite Program.cs with two-stage bootstrap and update appsettings.json** - `251d7f7` (feat)
2. **Task 2: Verify structured logging pipeline end-to-end** - checkpoint approved, no code commit

## Files Created/Modified

- `src/Starter.WebApi/Program.cs` - Rewritten with bootstrap logger, try/catch/finally, AddAppLogging, UseAppRequestLogging, Log.CloseAndFlush
- `src/Starter.WebApi/appsettings.json` - Complete Serilog configuration replacing old Logging section; 4 sink sections with Enabled flags, enrichers, Properties, RequestLogging
- `src/Starter.WebApi/appsettings.Development.json` - Serilog Debug-level overrides; old Logging section removed

## Decisions Made

- Bootstrap logger and try/catch/finally live in Program.cs, not inside the Starter.Logging module. This is mandatory: the bootstrap logger must exist before any module loads, and finally/CloseAndFlush must run after everything shuts down. Encapsulating them in the module is an anti-pattern identified in research.
- UseAppRequestLogging placed after UseAppExceptionHandling and UseHttpsRedirection. This ensures exception handling wraps request logs and HTTPS redirect does not appear in request logs as a duplicate entry.
- Old built-in Logging section removed from appsettings.json. Serilog's ReadFrom.Configuration fully replaces the built-in pipeline; keeping both creates confusing duplicate configuration.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. All optional sinks (File, Seq, OpenTelemetry) are disabled by default and require only setting `Enabled: true` in appsettings.json to activate.

## Next Phase Readiness

- Phase 2 Observability is now fully complete: Starter.Logging module (Plan 01) + Program.cs integration (Plan 02)
- Phase 3 (Data Layer) can begin; logging is available for all EF Core query logging and migration output
- Phase 4 (Security) can rely on correlation ID propagation already in place
- No blockers from this plan

---
*Phase: 02-observability*
*Completed: 2026-03-18*
