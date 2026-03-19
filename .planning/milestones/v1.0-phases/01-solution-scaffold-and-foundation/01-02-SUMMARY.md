---
phase: 01-solution-scaffold-and-foundation
plan: 02
subsystem: infra
tags: [dotnet10, iexceptionhandler, problemdetails, rfc7807, exception-mapping, diagnostics]

# Dependency graph
requires:
  - phase: 01-solution-scaffold-and-foundation/01
    provides: "Solution structure, custom exception hierarchy, ExceptionHandlingExtensions skeleton"
provides:
  - "GlobalExceptionHandler with typed exception mapping (5 custom + default 500)"
  - "RFC 7807 ProblemDetails responses with traceId and conditional stack traces"
  - "DiagnosticsController for manual exception pipeline verification"
affects: [phase-2, phase-4, phase-5, phase-6]

# Tech tracking
tech-stack:
  added: []
  patterns: ["IExceptionHandler typed exception mapping via switch expression", "ProblemDetails with conditional stackTrace based on environment + options", "Development-only controller guard via IHostEnvironment"]

key-files:
  created:
    - "src/Starter.ExceptionHandling/Handlers/GlobalExceptionHandler.cs"
    - "src/Starter.WebApi/Controllers/DiagnosticsController.cs"
  modified:
    - "src/Starter.ExceptionHandling/ExceptionHandlingExtensions.cs"

key-decisions:
  - "GlobalExceptionHandler logs before returning true to handle .NET 10 SuppressDiagnosticsCallback behavior"
  - "DiagnosticsController uses runtime IsDevelopment() guard rather than build-time exclusion"

patterns-established:
  - "IExceptionHandler: log first, then map exception to status code, then write ProblemDetails"
  - "Development-only controllers use EnsureDevelopment() guard that throws ForbiddenException in non-Development"

requirements-completed: [EXCP-01, EXCP-02, EXCP-03, EXCP-04, EXCP-05]

# Metrics
duration: 8min
completed: 2026-03-18
---

# Phase 1 Plan 02: Exception Handler Implementation Summary

**IExceptionHandler with typed exception-to-HTTP-status mapping returning RFC 7807 ProblemDetails with traceId, conditional stack traces, and DiagnosticsController for pipeline verification**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-18T09:50:00Z
- **Completed:** 2026-03-18T09:58:28Z
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 3

## Accomplishments
- Implemented GlobalExceptionHandler (internal sealed) mapping NotFoundException->404, AppValidationException->422, ConflictException->409, UnauthorizedException->401, ForbiddenException->403, and default->500
- All responses follow RFC 7807 ProblemDetails with type, title, status, detail, instance, traceId; Development includes stackTrace; validation errors include errors dictionary
- Created DiagnosticsController with 6 endpoints to trigger each exception type, guarded by IsDevelopment() check
- Human-verified all 6 endpoints return correct ProblemDetails responses with expected status codes and fields

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement GlobalExceptionHandler and register in extension method** - `f7edff6` (feat)
2. **Task 2: Create DiagnosticsController and verify full exception handling pipeline** - `36998a4` (feat)
3. **Task 3: Verify exception handling pipeline end-to-end** - checkpoint (human-verify, approved)

## Files Created/Modified
- `src/Starter.ExceptionHandling/Handlers/GlobalExceptionHandler.cs` - IExceptionHandler with typed exception mapping switch expression, conditional stack traces, traceId
- `src/Starter.ExceptionHandling/ExceptionHandlingExtensions.cs` - Added AddExceptionHandler<GlobalExceptionHandler>() registration
- `src/Starter.WebApi/Controllers/DiagnosticsController.cs` - 6 endpoints (not-found, validation, conflict, unauthorized, forbidden, unhandled) with IsDevelopment() guard

## Decisions Made
- GlobalExceptionHandler logs via ILogger.LogError before returning true, ensuring exceptions are captured even if .NET 10 SuppressDiagnosticsCallback suppresses default diagnostics after handler returns true
- DiagnosticsController uses runtime IsDevelopment() guard (EnsureDevelopment method) rather than preprocessor directives, so the controller exists in all environments but returns 403 Forbidden outside Development

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 1 is now complete: solution scaffold + exception handling pipeline fully functional
- All 15 Phase 1 requirements satisfied (FOUND-01 through FOUND-07, CONF-01 through CONF-03, EXCP-01 through EXCP-05)
- Ready for Phase 2: Observability (Serilog structured logging module)
- Exception handling pipeline is in place so any future module errors will be properly caught and formatted

## Self-Check: PASSED

All 3 created/modified files verified present. Both task commits (f7edff6, 36998a4) verified in git log. Solution builds with 0 errors.

---
*Phase: 01-solution-scaffold-and-foundation*
*Completed: 2026-03-18*
