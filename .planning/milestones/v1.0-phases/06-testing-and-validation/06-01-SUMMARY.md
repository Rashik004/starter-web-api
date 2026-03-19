---
phase: 06-testing-and-validation
plan: 01
subsystem: testing
tags: [xunit, moq, fluentassertions, netarchtest, webapplicationfactory, sqlite, integration-tests, unit-tests]

# Dependency graph
requires:
  - phase: 03-data-layer
    provides: TodoService, TodoItem, AppDbContext, IRepository, EfRepository
  - phase: 04-security-api
    provides: Auth pipeline (PolicyScheme, JWT, Identity), Controllers
  - phase: 05-production-hardening
    provides: RateLimiting, Caching, HealthChecks, Compression, Responses modules
provides:
  - Three compilable test projects (integration, unit, architecture) in solution
  - CustomWebApplicationFactory with SQLite in-memory and fake auth
  - AuthWebApplicationFactory with SQLite in-memory and real auth pipeline
  - 8 passing TodoService unit tests demonstrating Moq + FluentAssertions pattern
  - FakeAuthHandler and TestConstants shared helpers
  - appsettings.Testing.json with all required config sections
affects: [06-02, 06-03]

# Tech tracking
tech-stack:
  added: [xunit 2.9.3, xunit.runner.visualstudio 3.1.4, FluentAssertions 7.2.0, Moq 4.20.72, NetArchTest.Rules 1.3.2, Microsoft.AspNetCore.Mvc.Testing 10.0.4, coverlet.collector 6.0.4]
  patterns: [WebApplicationFactory with SQLite in-memory, FakeAuthHandler for test auth bypass, Moq unit test pattern for service-layer testing]

key-files:
  created:
    - tests/Starter.WebApi.Tests.Integration/Starter.WebApi.Tests.Integration.csproj
    - tests/Starter.WebApi.Tests.Unit/Starter.WebApi.Tests.Unit.csproj
    - tests/Starter.WebApi.Tests.Architecture/Starter.WebApi.Tests.Architecture.csproj
    - tests/Starter.WebApi.Tests.Integration/CustomWebApplicationFactory.cs
    - tests/Starter.WebApi.Tests.Integration/AuthWebApplicationFactory.cs
    - tests/Starter.WebApi.Tests.Integration/Helpers/FakeAuthHandler.cs
    - tests/Starter.WebApi.Tests.Integration/Helpers/TestConstants.cs
    - tests/Starter.WebApi.Tests.Integration/appsettings.Testing.json
    - tests/Starter.WebApi.Tests.Unit/Services/TodoServiceTests.cs
  modified:
    - Starter.WebApi.slnx
    - src/Starter.Data/Starter.Data.csproj

key-decisions:
  - "Used Content Update (not Include) for appsettings.Testing.json since Microsoft.NET.Sdk.Web auto-includes content files"
  - "Added DynamicProxyGenAssembly2 InternalsVisibleTo to Starter.Data.csproj so Moq can proxy IRepository<TodoItem> with internal generic argument"
  - "Kept xunit.runner.visualstudio 3.1.4 and Microsoft.NET.Test.Sdk 17.14.1 from template (newer compatible versions vs research-specified 2.8.2/17.13.0)"

patterns-established:
  - "WebApplicationFactory pattern: CustomWebApplicationFactory replaces DB with SQLite in-memory, overrides auth with FakeAuthHandler, loads appsettings.Testing.json"
  - "Auth flow test pattern: AuthWebApplicationFactory keeps real auth pipeline, only overrides DB and config"
  - "Unit test pattern: Mock<IRepository<T>> + direct TodoService instantiation with FluentAssertions"
  - "Test naming convention: MethodName_Scenario_ExpectedResult"

requirements-completed: [TEST-01, TEST-05]

# Metrics
duration: 9min
completed: 2026-03-19
---

# Phase 6 Plan 01: Test Foundation Summary

**Three test projects (integration, unit, architecture) with shared WebApplicationFactory infrastructure and 8 passing TodoService unit tests using Moq + FluentAssertions**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-19T05:54:02Z
- **Completed:** 2026-03-19T06:03:19Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Three test projects created, compiled, and registered in solution under /Tests folder
- CustomWebApplicationFactory boots full app with SQLite in-memory DB, fake auth, and appsettings.Testing.json
- AuthWebApplicationFactory boots full app with SQLite in-memory DB and real auth pipeline (for auth flow round-trip tests)
- 8 TodoService unit tests pass covering GetById, GetAll, Create, Update, Delete with success and failure paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Create three test projects, wire solution, add InternalsVisibleTo** - `6237f62` (feat)
2. **Task 2: Create integration test infrastructure and unit tests** - `6d29ee1` (feat)

## Files Created/Modified
- `tests/Starter.WebApi.Tests.Integration/Starter.WebApi.Tests.Integration.csproj` - Integration test project with Microsoft.NET.Sdk.Web, Mvc.Testing, FluentAssertions, EF Core Sqlite
- `tests/Starter.WebApi.Tests.Unit/Starter.WebApi.Tests.Unit.csproj` - Unit test project with Moq, FluentAssertions
- `tests/Starter.WebApi.Tests.Architecture/Starter.WebApi.Tests.Architecture.csproj` - Architecture test project with NetArchTest.Rules
- `Starter.WebApi.slnx` - Added /Tests/ folder with all 3 test projects
- `src/Starter.Data/Starter.Data.csproj` - Added InternalsVisibleTo for integration/unit test projects and DynamicProxyGenAssembly2
- `tests/Starter.WebApi.Tests.Integration/CustomWebApplicationFactory.cs` - Shared factory with SQLite in-memory + fake auth
- `tests/Starter.WebApi.Tests.Integration/AuthWebApplicationFactory.cs` - Factory with real auth pipeline for auth flow tests
- `tests/Starter.WebApi.Tests.Integration/Helpers/FakeAuthHandler.cs` - Auto-succeeds with configurable test claims
- `tests/Starter.WebApi.Tests.Integration/Helpers/TestConstants.cs` - Shared test identity constants
- `tests/Starter.WebApi.Tests.Integration/appsettings.Testing.json` - All config sections for ValidateOnStart compliance
- `tests/Starter.WebApi.Tests.Unit/Services/TodoServiceTests.cs` - 8 unit tests for TodoService

## Decisions Made
- Used `Content Update` instead of `Content Include` for appsettings.Testing.json because `Microsoft.NET.Sdk.Web` auto-includes content files, causing NETSDK1022 duplicate item errors
- Added `DynamicProxyGenAssembly2` to Starter.Data InternalsVisibleTo so Moq's Castle.DynamicProxy can create proxies for `IRepository<TodoItem>` (TodoItem is internal)
- Kept template-generated package versions (xunit.runner.visualstudio 3.1.4, Microsoft.NET.Test.Sdk 17.14.1) which are newer but compatible with the research-specified versions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Content Include vs Update for Sdk.Web project**
- **Found during:** Task 1 (Create test projects)
- **Issue:** `Content Include="appsettings.Testing.json"` caused NETSDK1022 duplicate item error because Microsoft.NET.Sdk.Web auto-includes content files
- **Fix:** Changed to `Content Update="appsettings.Testing.json"` to only set CopyToOutputDirectory
- **Files modified:** tests/Starter.WebApi.Tests.Integration/Starter.WebApi.Tests.Integration.csproj
- **Verification:** `dotnet build` succeeds
- **Committed in:** 6237f62 (Task 1 commit)

**2. [Rule 3 - Blocking] Created placeholder appsettings.Testing.json for Task 1 build**
- **Found during:** Task 1 (Create test projects)
- **Issue:** Integration csproj references appsettings.Testing.json for CopyToOutputDirectory but the file was planned for Task 2. Build fails without the file existing.
- **Fix:** Created empty JSON placeholder during Task 1, populated with full content in Task 2
- **Files modified:** tests/Starter.WebApi.Tests.Integration/appsettings.Testing.json
- **Verification:** `dotnet build` succeeds
- **Committed in:** 6237f62 (Task 1 commit)

**3. [Rule 1 - Bug] Added DynamicProxyGenAssembly2 InternalsVisibleTo for Moq**
- **Found during:** Task 2 (Create unit tests)
- **Issue:** Moq's Castle.DynamicProxy cannot create proxy for `IRepository<TodoItem>` because `TodoItem` is internal. Runtime error: "type Starter.Data.Entities.TodoItem is not accessible"
- **Fix:** Added `InternalsVisibleTo Include="DynamicProxyGenAssembly2"` to Starter.Data.csproj
- **Files modified:** src/Starter.Data/Starter.Data.csproj
- **Verification:** All 8 unit tests pass
- **Committed in:** 6d29ee1 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking)
**Impact on plan:** All auto-fixes necessary for correct build and test execution. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Integration test infrastructure (CustomWebApplicationFactory, AuthWebApplicationFactory) ready for Plan 02 to add health check, auth flow, and CRUD tests
- Architecture test project ready for Plan 03 to add module isolation and removal tests
- Unit test pattern established for any additional service-layer tests

## Self-Check: PASSED

All 9 created files verified present. Both task commits (6237f62, 6d29ee1) verified in git log.

---
*Phase: 06-testing-and-validation*
*Completed: 2026-03-19*
