---
phase: 04-security-and-api-surface
plan: 05
subsystem: api
tags: [controllers, auth-endpoints, api-versioning, fluentvalidation, jwt, aspnet-identity, google-oauth]

# Dependency graph
requires:
  - phase: 04-01
    provides: Auth.Shared with AppUser, AuthConstants, JwtOptions
  - phase: 04-02
    provides: Versioning with ApiVersion attributes, CORS, FluentValidation DI registration
  - phase: 04-03
    provides: Auth.Identity with UserManager/SignInManager, Auth.Jwt with JwtTokenService, Auth.Google with conditional OAuth
provides:
  - AuthController with register, login, and Google OAuth endpoints returning JWT tokens
  - TodoController versioned at /api/v1/todos with [Authorize] and FluentValidation
  - TodoV2Controller at /api/v2/todos with expanded DTO (priority, dueDate, tags)
  - FluentValidation validators for all 6 request DTOs
  - V2 service methods on ITodoService and TodoService
affects: [04-06, 05-hardening, 06-testing]

# Tech tracking
tech-stack:
  added: [FluentValidation.DependencyInjectionExtensions 12.1.1 (explicit in Host)]
  patterns: [manual IValidator<T> injection via [FromServices], AppValidationException throw for GlobalExceptionHandler integration, ApiVersionNeutral for infrastructure routes]

key-files:
  created:
    - src/Starter.WebApi/Controllers/AuthController.cs
    - src/Starter.WebApi/Controllers/TodoV2Controller.cs
    - src/Starter.WebApi/Models/LoginRequest.cs
    - src/Starter.WebApi/Models/RegisterRequest.cs
    - src/Starter.WebApi/Models/CreateTodoV2Request.cs
    - src/Starter.WebApi/Models/UpdateTodoV2Request.cs
    - src/Starter.WebApi/Validators/LoginRequestValidator.cs
    - src/Starter.WebApi/Validators/RegisterRequestValidator.cs
    - src/Starter.WebApi/Validators/CreateTodoRequestValidator.cs
    - src/Starter.WebApi/Validators/UpdateTodoRequestValidator.cs
    - src/Starter.WebApi/Validators/CreateTodoV2RequestValidator.cs
    - src/Starter.WebApi/Validators/UpdateTodoV2RequestValidator.cs
  modified:
    - src/Starter.WebApi/Controllers/TodoController.cs
    - src/Starter.Shared/Contracts/ITodoService.cs
    - src/Starter.Data/Services/TodoService.cs
    - src/Starter.WebApi/Starter.WebApi.csproj

key-decisions:
  - "AuthController uses [ApiVersionNeutral] -- auth is infrastructure, not a versioned business API"
  - "FluentValidation.DependencyInjectionExtensions added directly to Host csproj for explicitness despite transitive availability from Starter.Validation"

patterns-established:
  - "Manual validation pattern: inject IValidator<T> via [FromServices], validate, throw AppValidationException on failure -- consistent across all controllers"
  - "V2 expansion pattern: add V2 methods to ITodoService, implement in TodoService with separate MapToV2Dto, create V2 controller at [ApiVersion(2.0)]"

requirements-completed: [AUTH-02, VERS-03, VALD-02, VALD-03]

# Metrics
duration: 3min
completed: 2026-03-18
---

# Phase 4 Plan 5: Controllers & Validation Summary

**AuthController with JWT register/login/Google OAuth, versioned TodoControllers (v1/v2), and FluentValidation validators for all 6 request DTOs using manual injection pattern**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-18T17:15:58Z
- **Completed:** 2026-03-18T17:19:33Z
- **Tasks:** 3
- **Files modified:** 16

## Accomplishments
- AuthController at /api/auth with register (201 + auto-login JWT), login (200 + JWT with lockout), and Google OAuth (redirect + callback with auto-create user)
- TodoController upgraded to [ApiVersion(1.0)] at /api/v{version}/todos with [Authorize] and FluentValidation manual injection
- TodoV2Controller at [ApiVersion(2.0)] with expanded TodoItemV2Dto (priority, dueDate, tags) and v2 service methods
- Six FluentValidation validators covering all request DTOs with priority enum validation for v2

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AuthController with register, login, and Google OAuth endpoints** - `6b63cc5` (feat)
2. **Task 2: Version TodoController (v1) and create TodoV2Controller with expanded DTO** - `3a68649` (feat)
3. **Task 3: Create FluentValidation validators for all request DTOs** - `af972ba` (feat)

## Files Created/Modified
- `src/Starter.WebApi/Controllers/AuthController.cs` - Register, login, Google OAuth endpoints with JWT token generation
- `src/Starter.WebApi/Controllers/TodoController.cs` - Updated with [ApiVersion(1.0)], versioned route, [Authorize], FluentValidation
- `src/Starter.WebApi/Controllers/TodoV2Controller.cs` - V2 todo endpoints with expanded DTO fields
- `src/Starter.WebApi/Models/LoginRequest.cs` - Login DTO with email and password
- `src/Starter.WebApi/Models/RegisterRequest.cs` - Register DTO with email, password, confirmPassword
- `src/Starter.WebApi/Models/CreateTodoV2Request.cs` - V2 create DTO with priority, dueDate, tags
- `src/Starter.WebApi/Models/UpdateTodoV2Request.cs` - V2 update DTO with priority, dueDate, tags
- `src/Starter.WebApi/Validators/LoginRequestValidator.cs` - Email format and password required
- `src/Starter.WebApi/Validators/RegisterRequestValidator.cs` - Email, password min 8 chars, confirm match
- `src/Starter.WebApi/Validators/CreateTodoRequestValidator.cs` - Title required, max 200 chars
- `src/Starter.WebApi/Validators/UpdateTodoRequestValidator.cs` - Title required, max 200 chars
- `src/Starter.WebApi/Validators/CreateTodoV2RequestValidator.cs` - Title + priority enum (Low/Medium/High) + tags max 500
- `src/Starter.WebApi/Validators/UpdateTodoV2RequestValidator.cs` - Title + priority enum + tags max 500
- `src/Starter.Shared/Contracts/ITodoService.cs` - Added V2 method signatures (GetAllV2, GetByIdV2, CreateV2, UpdateV2)
- `src/Starter.Data/Services/TodoService.cs` - V2 implementations with TodoPriority parsing and MapToV2Dto
- `src/Starter.WebApi/Starter.WebApi.csproj` - Added FluentValidation.DependencyInjectionExtensions 12.1.1

## Decisions Made
- AuthController uses [ApiVersionNeutral] -- auth is infrastructure, not a versioned business API
- FluentValidation.DependencyInjectionExtensions added directly to Host csproj for explicitness despite transitive availability from Starter.Validation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All controllers wired with auth, versioning, and validation
- Plan 04-06 (Program.cs wiring) can integrate all module AddApp*/UseApp* calls
- GlobalExceptionHandler integration complete -- AppValidationException produces 422 ProblemDetails

## Self-Check: PASSED

All 16 files verified present. All 3 task commits verified (6b63cc5, 3a68649, af972ba).

---
*Phase: 04-security-and-api-surface*
*Completed: 2026-03-18*
