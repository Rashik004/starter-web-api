# Phase 6: Testing and Validation - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Add comprehensive test coverage that validates module functionality and — critically — proves the core differentiator: any module can be removed without breaking the build. Three test projects cover integration tests (WebApplicationFactory), unit tests (service-layer with Moq), and architectural tests (NetArchTest for module isolation + module removal smoke tests).

</domain>

<decisions>
## Implementation Decisions

### Test project organization
- Three separate test projects: `Starter.WebApi.Tests.Integration`, `Starter.WebApi.Tests.Unit`, `Starter.WebApi.Tests.Architecture`
- Test projects live in `tests/` directory (parallel to `src/`)
- All three projects grouped under a `/Tests` solution folder in the .slnx
- Integration tests use a shared `CustomWebApplicationFactory` base class that configures SQLite in-memory, disables external services, and seeds test data
- Fresh SQLite in-memory database per test class (unique connection string per fixture) — full test isolation, no ordering dependencies

### Integration test auth strategy
- Fake authentication handler for most integration tests — auto-authenticates with configurable claims, tests focus on endpoint behavior not auth plumbing
- Auth flow tests (TEST-03) use full round-trip: register user → login → get JWT → call protected endpoint with real token → verify access (proves the auth pipeline end-to-end against real in-memory Identity store)
- Google OAuth is NOT tested in integration tests — external redirect not feasible in WebApplicationFactory
- Identity + JWT auth flows cover the testable auth pipeline

### Test libraries & assertions
- **Test runner:** xUnit — standard .NET test framework with IClassFixture support
- **Assertions:** FluentAssertions — `.Should().Be()` style for readable test assertions
- **Mocking:** Moq — `mock.Setup(x => x.Method()).ReturnsAsync(value)` for unit test dependencies (user preference over NSubstitute despite roadmap mention)
- **Architecture:** NetArchTest — for enforcing no module-to-module references
- **Test naming:** `MethodName_Scenario_ExpectedResult` convention (e.g., `GetByIdAsync_WhenItemExists_ReturnsDto`)

### Claude's Discretion
- Module removal smoke test approach (script-based, MSBuild, or programmatic)
- Which specific modules to include in removal smoke tests (all 20 or a representative subset)
- CustomWebApplicationFactory implementation details (service overrides, test data seeding)
- Exact fake auth handler implementation
- Test data fixtures and helper utilities
- Whether to include test configuration files (appsettings.Testing.json)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project foundation
- `.planning/phases/01-solution-scaffold-and-foundation/01-CONTEXT.md` — Extension method naming (`AddApp*`/`UseApp*`), module naming (`Starter.{Module}`), removability test pattern
- `.planning/REQUIREMENTS.md` — TEST-01..TEST-07 define the scope for this phase

### Module registration (critical for removal tests)
- `src/Starter.WebApi/Program.cs` — All 15 `AddApp*` and 7 `UseApp*` calls that define module registration; removal tests must verify builds succeed without each one
- `src/Starter.WebApi/Starter.WebApi.csproj` — All 19 project references that correspond to removable modules

### Service layer (unit test target)
- `src/Starter.Data/Services/TodoService.cs` — Primary service for unit test demonstration, uses `IRepository<TodoItem>` dependency
- `src/Starter.Shared/Contracts/ITodoService.cs` — Service contract interface
- `src/Starter.Shared/Contracts/IRepository.cs` — Repository contract for mocking

### Auth pipeline (integration test target)
- `src/Starter.Auth.Jwt/` — JWT token service for auth flow round-trip tests
- `src/Starter.Auth.Identity/` — Identity registration/login for TEST-03

### Health checks (integration test target)
- `src/Starter.HealthChecks/` — Health check module for TEST-02

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/` directory exists with `.gitkeep` — ready for test project creation
- `Starter.WebApi.slnx` — solution file to add test projects to
- `TodoService` — clean service with `IRepository<T>` dependency, ideal for demonstrating Moq-based unit tests
- `IRepository<T>` and `ITodoService` interfaces in `Starter.Shared/Contracts/` — ready to mock

### Established Patterns
- `AddApp*`/`UseApp*` extension method pattern — every module follows this, making removal tests systematic
- `internal` visibility by default — test projects will need `InternalsVisibleTo` for any internal type access
- IOptions<T> with ValidateOnStart — CustomWebApplicationFactory must provide valid config sections
- Grouped-by-concern Program.cs — removal tests can target specific line groups

### Integration Points
- `Program.cs` is the composition root — WebApplicationFactory<Program> will boot the full pipeline
- 19 project references in Host .csproj — each represents a removable module
- `appsettings.json` — test factory needs to override database, auth, and other config sections
- Solution file — 3 new test projects to add under /Tests folder

</code_context>

<specifics>
## Specific Ideas

- The module removal smoke tests are the most important tests in this phase — they prove the core value proposition of the entire starter repo
- Auth flow round-trip should demonstrate a complete "new user experience": register → immediately get token → use token → access protected resource
- Unit tests on TodoService should demonstrate the Moq pattern clearly — this is what users will copy when adding their own services
- Architectural tests should catch the exact violation pattern: a module class library directly referencing another module (not through Shared interfaces)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-testing-and-validation*
*Context gathered: 2026-03-19*
