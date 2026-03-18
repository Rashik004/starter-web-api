---
phase: 04-security-and-api-surface
plan: 04
subsystem: api
tags: [openapi, scalar, swagger, jwt, bearer, documentation]

# Dependency graph
requires:
  - phase: 04-02
    provides: Versioning GroupNameFormat producing "v1" and "v2" document names
provides:
  - Starter.OpenApi module with AddAppOpenApi/UseAppOpenApi extension methods
  - Per-version OpenAPI 3.1 documents (v1, v2) with Bearer security scheme
  - Config-driven Scalar interactive API documentation UI
affects: [04-06, 05-hardening, 06-testing]

# Tech tracking
tech-stack:
  added: [Microsoft.AspNetCore.OpenApi 10.0.5, Scalar.AspNetCore 2.13.11]
  patterns: [IOpenApiDocumentTransformer for security scheme injection, config-driven UI visibility]

key-files:
  created:
    - src/Starter.OpenApi/Starter.OpenApi.csproj
    - src/Starter.OpenApi/Options/OpenApiOptions.cs
    - src/Starter.OpenApi/Transformers/BearerSecuritySchemeTransformer.cs
    - src/Starter.OpenApi/OpenApiExtensions.cs
  modified: []

key-decisions:
  - "Adapted BearerSecuritySchemeTransformer for Microsoft.OpenApi v2.0.0 breaking changes (namespace, property, and type changes)"
  - "Used OpenApiSecuritySchemeReference instead of OpenApiSecurityScheme with OpenApiReference for security requirements (v2.0.0 API change)"

patterns-established:
  - "IOpenApiDocumentTransformer: implement interface to inject security schemes, metadata, or custom transformations into OpenAPI documents"
  - "Config-driven UI: Use options class with boolean flag (EnableScalar) rather than environment checks for flexibility"

requirements-completed: [DOCS-01, DOCS-02, DOCS-03, DOCS-04]

# Metrics
duration: 7min
completed: 2026-03-18
---

# Phase 4 Plan 4: OpenAPI & Scalar Summary

**OpenAPI 3.1 multi-version documents (v1, v2) with Bearer security scheme transformer and config-driven Scalar interactive UI using Microsoft.OpenApi v2.0.0**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-18T17:05:42Z
- **Completed:** 2026-03-18T17:12:29Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Starter.OpenApi module with Microsoft.AspNetCore.OpenApi 10.0.5 and Scalar.AspNetCore 2.13.11
- BearerSecuritySchemeTransformer adds JWT Bearer security scheme to OpenAPI documents for Scalar authorize button
- AddAppOpenApi registers per-version (v1, v2) OpenAPI documents matching Versioning GroupNameFormat
- UseAppOpenApi maps OpenAPI endpoints and config-driven Scalar UI with version dropdown

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Starter.OpenApi project with OpenApiOptions and BearerSecuritySchemeTransformer** - `4df6d92` (feat)
2. **Task 2: Create OpenApiExtensions with multi-version document registration and Scalar UI** - `a8ba798` (feat)

**Plan metadata:** _pending_ (docs: complete plan)

## Files Created/Modified
- `src/Starter.OpenApi/Starter.OpenApi.csproj` - Project file with OpenApi and Scalar NuGet references
- `src/Starter.OpenApi/Options/OpenApiOptions.cs` - Config-driven options with EnableScalar, Title, Description
- `src/Starter.OpenApi/Transformers/BearerSecuritySchemeTransformer.cs` - JWT Bearer security scheme document transformer
- `src/Starter.OpenApi/OpenApiExtensions.cs` - AddAppOpenApi (v1+v2 docs) and UseAppOpenApi (Scalar UI) extensions

## Decisions Made
- Adapted BearerSecuritySchemeTransformer for Microsoft.OpenApi v2.0.0 breaking changes: namespace moved from `Microsoft.OpenApi.Models` to `Microsoft.OpenApi`, `document.SecurityRequirements` renamed to `document.Security`, `OpenApiSecuritySchemeReference` replaces `OpenApiSecurityScheme` with `OpenApiReference` as security requirement key
- Used `IDictionary<string, IOpenApiSecurityScheme>` for SecuritySchemes null-coalescing (v2.0.0 changed property type from concrete to interface)
- Used `List<string>()` instead of `Array.Empty<string>()` for security requirement scopes (v2.0.0 expects `List<string>` not `string[]`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Microsoft.OpenApi v2.0.0 namespace and API breaking changes**
- **Found during:** Task 1 (BearerSecuritySchemeTransformer)
- **Issue:** Plan assumed Microsoft.OpenApi v1.x namespace `Microsoft.OpenApi.Models` but transitive dependency pulled v2.0.0 which moved all types to `Microsoft.OpenApi` root namespace, renamed `SecurityRequirements` to `Security`, and changed `OpenApiSecurityRequirement` key type from `OpenApiSecurityScheme` to `OpenApiSecuritySchemeReference`
- **Fix:** Updated namespace import, property name, and security requirement construction to match v2.0.0 API
- **Files modified:** src/Starter.OpenApi/Transformers/BearerSecuritySchemeTransformer.cs
- **Verification:** `dotnet build` succeeds with 0 errors and 0 warnings
- **Committed in:** 4df6d92 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug - API version mismatch)
**Impact on plan:** Essential fix for correctness. Microsoft.OpenApi v2.0.0 is a major version with breaking changes. No scope creep.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- OpenAPI module ready for wiring into Program.cs (Plan 06)
- GenerateDocumentationFile for XML comment support will be added in Plan 06
- Scalar UI accessible at /scalar/ when enabled via OpenApi:EnableScalar config

---
*Phase: 04-security-and-api-surface*
*Completed: 2026-03-18*

## Self-Check: PASSED

All 4 created files verified on disk. Both task commits (4df6d92, a8ba798) found in git log.
