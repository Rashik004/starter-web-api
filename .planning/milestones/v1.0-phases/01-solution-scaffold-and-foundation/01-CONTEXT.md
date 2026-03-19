# Phase 1: Solution Scaffold and Foundation - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Create the compilable .NET 10 solution structure with Host + Shared projects, the extension method composition pattern, IOptions configuration validation, and global exception handling via IExceptionHandler. The exception handling module doubles as the sample module that proves the removability pattern. Other module projects are created in their respective phases.

</domain>

<decisions>
## Implementation Decisions

### Project scaffolding
- Minimal scaffold: Host + Shared + ExceptionHandling module only — other module projects created in their respective phases
- Exception handling module (Starter.ExceptionHandling) is the sample module that proves the removability pattern — no throwaway demo code
- Solution uses solution folders in the .sln to group projects (e.g., /Modules, /Tests, /Host) for Visual Studio Solution Explorer organization
- Program.cs has grouped-by-concern layout with comment sections: Observability, Security, Data, API

### Naming conventions
- Extension method prefix: `AddApp*` / `UseApp*` (e.g., `builder.Services.AddAppExceptionHandling()`, `app.UseAppExceptionHandling()`)
- Host project: `Starter.WebApi`
- Shared contracts project: `Starter.Shared`
- Module class libraries: `Starter.{Module}` (e.g., `Starter.ExceptionHandling`, `Starter.Auth`, `Starter.Logging`)
- Solution name: `Starter.WebApi.sln`

### Exception handling
- Extended ProblemDetails shape: standard RFC 7807 fields + `traceId` + `errors` object for consistency with validation errors
- Typed exception mapping: specific exception types map to HTTP status codes (NotFoundException -> 404, ValidationException -> 422, UnauthorizedException -> 401, etc.)
- Custom exception types live in Starter.Shared so all modules can throw them and the exception handler catches them
- Uses built-in IExceptionHandler (not custom middleware)
- Stack traces included in Development, hidden in Production

### Claude's Discretion
- Exact solution folder grouping names and structure
- Which specific exception types to include initially
- IOptions ValidateOnStart wiring pattern details
- appsettings.json section naming conventions
- Whether to include a sample controller in the Host project for Phase 1 testing

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project research
- `.planning/research/STACK.md` — Verified .NET 10 package versions, IExceptionHandler as recommended pattern, IOptions ValidateOnStart convention
- `.planning/research/ARCHITECTURE.md` — Solution structure, extension method composition pattern, middleware ordering, Shared project conventions
- `.planning/research/PITFALLS.md` — IOptions without ValidateOnStart silently binds to defaults, module cross-coupling prevention, internal visibility by default

### Requirements
- `.planning/REQUIREMENTS.md` — FOUND-01..07, CONF-01..03, EXCP-01..05 define the scope for this phase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — this phase establishes the foundational patterns all other phases will follow

### Integration Points
- Program.cs is the composition root — all future modules register here
- Starter.Shared is the contract layer — all future modules reference this for shared types
- appsettings.json section naming established here becomes the convention for all modules

</code_context>

<specifics>
## Specific Ideas

- Program.cs should look like the "grouped by concern" preview from project initialization:
  ```csharp
  // --- Observability ---
  // (Phase 2)

  // --- Security ---
  // (Phase 4)

  // --- Data ---
  // (Phase 3)

  // --- API ---
  // (Phase 4+)

  app.UseAppExceptionHandling();
  ```
- The removability test: deleting `AddAppExceptionHandling()` + `UseAppExceptionHandling()` + the Starter.ExceptionHandling project reference should produce a clean build

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-solution-scaffold-and-foundation*
*Context gathered: 2026-03-18*
