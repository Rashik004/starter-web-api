---
phase: 03-data-layer
plan: 02
subsystem: database
tags: [ef-core, repository, service-layer, rest-api, crud, dto, validation, appsettings]

# Dependency graph
requires:
  - phase: 03-data-layer
    plan: 01
    provides: "AppDbContext, EfRepository/TodoService stubs, DataExtensions with AddAppData/UseAppData, IRepository<T>/ITodoService contracts"
  - phase: 01-solution-scaffold-and-foundation
    provides: "Solution structure, Program.cs composition root, GlobalExceptionHandler"
provides:
  - "EfRepository<T> with full CRUD operations (FindAsync, ToListAsync, SaveChangesAsync)"
  - "TodoService with entity-to-DTO mapping, NotFoundException on missing items, DateTime.UtcNow for creation"
  - "TodoController with 5 REST endpoints (GET all, GET by id, POST, PUT, DELETE)"
  - "CreateTodoRequest and UpdateTodoRequest with DataAnnotations validation"
  - "Program.cs wired with builder.AddAppData() and app.UseAppData()"
  - "appsettings.json Database section with Provider, AutoMigrate, CommandTimeout, ConnectionStrings for all 3 providers"
affects: [03-data-layer, 04-security-and-api, 05-hardening]

# Tech tracking
tech-stack:
  added: []
  patterns: [controller-service-repository vertical slice, request DTO validation with DataAnnotations, primary constructor DI in controllers]

key-files:
  created:
    - src/Starter.WebApi/Controllers/TodoController.cs
    - src/Starter.WebApi/Models/CreateTodoRequest.cs
    - src/Starter.WebApi/Models/UpdateTodoRequest.cs
  modified:
    - src/Starter.Data/Repositories/EfRepository.cs
    - src/Starter.Data/Services/TodoService.cs
    - src/Starter.WebApi/Program.cs
    - src/Starter.WebApi/appsettings.json
    - src/Starter.WebApi/appsettings.Development.json

key-decisions:
  - "TodoService.UpdateAsync throws NotFoundException instead of returning null, integrating with GlobalExceptionHandler for automatic 404 responses"
  - "TodoController uses primary constructor for ITodoService DI injection, consistent with AppDbContext and other service patterns"
  - "Database config section placed between ExceptionHandling and Serilog in appsettings.json for logical grouping"

patterns-established:
  - "Controller pattern: primary constructor DI, [ApiController] + [Route(api/[controller])], CancellationToken on all async actions"
  - "Request DTO pattern: sealed record with DataAnnotations ([Required], [StringLength]) for model validation"
  - "Service exception pattern: throw NotFoundException for missing entities, caught by GlobalExceptionHandler returning 404"

requirements-completed: [DATA-01, DATA-06]

# Metrics
duration: 3min
completed: 2026-03-18
---

# Phase 3 Plan 02: Repository, Service, and API Wiring Summary

**Full CRUD vertical slice from TodoController through TodoService to EfRepository with request DTOs, DataAnnotations validation, and appsettings.json Database/ConnectionStrings configuration**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-18T14:35:24Z
- **Completed:** 2026-03-18T14:38:08Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Finalized EfRepository and TodoService implementations: removed stub comments, added NotFoundException on update, renamed mapper to MapToDto
- Created TodoController with 5 CRUD endpoints returning proper HTTP status codes (200, 201, 204, 404)
- Added CreateTodoRequest and UpdateTodoRequest sealed records with Required and StringLength validation
- Wired builder.AddAppData() and app.UseAppData() into Program.cs composition root
- Configured appsettings.json with Database section (Provider, AutoMigrate, CommandTimeout, MaxRetryCount) and ConnectionStrings for all 3 providers
- Enabled sensitive data logging in appsettings.Development.json for SQL parameter visibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement EfRepository and TodoService with full CRUD logic** - `4b9e10b` (feat)
2. **Task 2: Create TodoController, request DTOs, wire Program.cs, and configure appsettings.json** - `3a7202a` (feat)

## Files Created/Modified
- `src/Starter.Data/Repositories/EfRepository.cs` - Updated doc comment from stub to production description
- `src/Starter.Data/Services/TodoService.cs` - NotFoundException on update, MapToDto naming, descriptive doc comment
- `src/Starter.WebApi/Controllers/TodoController.cs` - REST API with 5 CRUD endpoints using ITodoService
- `src/Starter.WebApi/Models/CreateTodoRequest.cs` - Request DTO with [Required, StringLength(200)] validation
- `src/Starter.WebApi/Models/UpdateTodoRequest.cs` - Request DTO with Title validation and IsComplete flag
- `src/Starter.WebApi/Program.cs` - Added using Starter.Data, builder.AddAppData(), app.UseAppData()
- `src/Starter.WebApi/appsettings.json` - Database section and ConnectionStrings for Sqlite, SqlServer, PostgreSql
- `src/Starter.WebApi/appsettings.Development.json` - EnableSensitiveDataLogging override for development

## Decisions Made

1. **NotFoundException on update instead of null return** - Plan specified throwing NotFoundException in UpdateAsync. This integrates with the GlobalExceptionHandler from Phase 1, which maps NotFoundException to HTTP 404 automatically. The controller's null check on UpdateAsync return is defensive but will not trigger since the service now throws before returning null.

2. **Database config placement** - Placed Database and ConnectionStrings sections between ExceptionHandling and Serilog in appsettings.json, maintaining the logical service-section ordering established in Phase 1.

3. **Development-only sensitive data logging** - Added Database.EnableSensitiveDataLogging=true in appsettings.Development.json to enable SQL parameter logging only in development environments, keeping production secure by default.

## Deviations from Plan

None - plan executed exactly as written. Plan 01 had already provided working implementations for EfRepository and TodoService rather than stubs, so Task 1 was primarily updating the NotFoundException behavior in UpdateAsync and renaming the mapper method.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Full vertical slice compiles: TodoController -> ITodoService -> IRepository<TodoItem> -> AppDbContext
- Plan 03 can generate initial migrations against all three providers
- API endpoints ready for Phase 4 authentication/authorization middleware
- GlobalExceptionHandler already maps NotFoundException -> 404 (tested in Phase 1)

## Self-Check: PASSED

All 8 files verified on disk. Both task commits (4b9e10b, 3a7202a) verified in git log. Solution builds with 0 errors, 0 warnings.

---
*Phase: 03-data-layer*
*Completed: 2026-03-18*
