# Phase 2: Observability - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Add Serilog structured logging as a removable module (`Starter.Logging`) with two-stage bootstrap pattern and configurable sinks (Console, File, Seq, OpenTelemetry). All sink configuration is driven by appsettings.json — no code changes to enable/disable sinks. The module is removable by deleting its extension method call and project reference.

</domain>

<decisions>
## Implementation Decisions

### Sink defaults and configuration shape
- Console sink is the only sink enabled by default out-of-the-box
- All sinks (Console, File, Seq, OpenTelemetry) have full config blocks in appsettings.json with JSON comments explaining how to enable each one
- Each sink section has an explicit `Enabled: true/false` flag (not presence-based) — requires custom registration logic to check the flag
- OpenTelemetry sink supports both generic OTLP endpoint URL and Azure Application Insights connection string, with both options documented in appsettings.json comments
- Sink configuration follows LOG-06: entirely appsettings-driven, zero code changes to enable/disable

### Bootstrap logger scope
- Bootstrap logger verbosity is Information level and above (captures startup milestones, not just errors)
- A swap marker log entry is written at Information level when transitioning from bootstrap to full Serilog pipeline (e.g., "Switching from bootstrap to full Serilog pipeline")
- `Log.CloseAndFlush()` is wired to application lifetime shutdown to guarantee all buffered log entries are flushed
- Bootstrap logger sink selection is Claude's discretion

### Request logging detail
- Health check endpoints (/health, /health/ready, /health/live) are excluded from `UseSerilogRequestLogging()` to prevent probe noise
- Log level is dynamic by HTTP status code: 200-399 → Information, 400-499 → Warning, 500+ → Error
- Extra properties enriched per request: client IP address, request/response content type, user agent string — all configurable (can be toggled on/off)
- Custom message template: `HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.0000}ms` (or similar clean, scannable format)

### Log enrichment strategy
- Built-in enrichers: Environment name + Machine name (enabled by default)
- Correlation ID: read from custom `X-Correlation-Id` header, fall back to `HttpContext.TraceIdentifier` — aligns with existing `traceId` field in GlobalExceptionHandler's ProblemDetails
- Enricher configuration is appsettings-driven (Serilog:Enrich section) — add/remove enrichers without code changes
- Application property: Claude's discretion (whether to include a custom 'Application' property from config)

### Claude's Discretion
- Bootstrap logger sink (console-only, console + emergency file, etc.)
- Application property enricher (include or skip)
- Exact config section structure and key naming within Serilog configuration
- Implementation of the "Enabled" flag checking for sinks
- Request property configurability mechanism (IOptions, Serilog config, etc.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project foundation
- `.planning/phases/01-solution-scaffold-and-foundation/01-CONTEXT.md` — Extension method naming (`AddApp*`/`UseApp*`), module naming (`Starter.{Module}`), Program.cs grouped-by-concern layout, internal visibility pattern
- `.planning/REQUIREMENTS.md` — LOG-01..LOG-06 define the scope for this phase

### Architecture patterns
- `.planning/research/ARCHITECTURE.md` — Solution structure, extension method composition pattern, middleware ordering, Shared project conventions
- `.planning/research/STACK.md` — Verified .NET 10 package versions, IOptions ValidateOnStart convention

### Existing code
- `src/Starter.WebApi/Program.cs` — Composition root with `// --- Observability ---` placeholder and `// (Phase 2: app.UseSerilogRequestLogging())` comment
- `src/Starter.ExceptionHandling/Handlers/GlobalExceptionHandler.cs` — Already uses `ILogger<GlobalExceptionHandler>` and sets `traceId` in ProblemDetails extensions
- `src/Starter.ExceptionHandling/ExceptionHandlingExtensions.cs` — Reference pattern for module extension methods (`AddApp*`/`UseApp*`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GlobalExceptionHandler` already uses `ILogger<GlobalExceptionHandler>` — will automatically route through Serilog once the pipeline is registered
- `ExceptionHandlingExtensions.cs` provides the reference pattern for `AddApp*`/`UseApp*` extension methods that the Logging module should follow

### Established Patterns
- IOptions<T> with ValidateDataAnnotations and ValidateOnStart — Logging module should follow this for its config section
- `internal` visibility by default; only extension methods are `public`
- Module config sections in appsettings.json (ExceptionHandling section already exists as an example)

### Integration Points
- `Program.cs` line 6: `// --- Observability ---` placeholder is where `AddAppLogging()` goes
- `Program.cs` line 24: `// (Phase 2: app.UseSerilogRequestLogging())` marks where `UseAppLogging()` goes in the middleware pipeline
- `appsettings.json` needs Serilog configuration sections added

</code_context>

<specifics>
## Specific Ideas

- The correlation ID from `X-Correlation-Id` header should align with the `traceId` already set in GlobalExceptionHandler's ProblemDetails — same value should appear in both log entries and error responses
- All extra request logging properties (client IP, content type, user agent) must be individually toggleable, not all-or-nothing
- The swap marker ("Switching from bootstrap to full Serilog pipeline") should be visible in the console during startup to clearly delineate the two logging stages

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-observability*
*Context gathered: 2026-03-18*
