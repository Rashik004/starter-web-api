---
phase: quick
plan: 260319-ity
type: execute
wave: 1
depends_on: []
files_modified:
  - CLAUDE.md
autonomous: true
requirements: [QUICK-260319-ity]

must_haves:
  truths:
    - "CLAUDE.md exists at repository root and is loaded automatically by Claude Code sessions"
    - "File covers project architecture, module patterns, coding conventions, and testing commands"
    - "Instructions are actionable — Claude can follow them without exploring the codebase"
  artifacts:
    - path: "CLAUDE.md"
      provides: "Agent instruction file for Claude Code"
      min_lines: 80
  key_links: []
---

<objective>
Create a CLAUDE.md agent instruction file at the repository root that gives Claude Code comprehensive context about the Starter.WebApi project — its architecture, module patterns, conventions, key decisions, and how to build/test/run.

Purpose: Claude Code automatically reads CLAUDE.md at session start. A well-crafted instruction file eliminates repetitive context-gathering and ensures Claude follows established project patterns from the first interaction.

Output: CLAUDE.md at repository root
</objective>

<execution_context>
@F:/Personal/bootstrapper-apps/web-api/.claude/get-shit-done/workflows/execute-plan.md
@F:/Personal/bootstrapper-apps/web-api/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@README.md
@src/Starter.WebApi/Program.cs
@Starter.WebApi.slnx
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create CLAUDE.md agent instruction file</name>
  <files>CLAUDE.md</files>
  <action>
Create CLAUDE.md at the repository root. The file must be structured for fast Claude comprehension (not human documentation — that is README.md). Include these sections:

**1. Project Identity (2-3 lines)**
- Modular .NET 10 Web API starter repo, namespace root `Starter.WebApi`
- Core value: every module is independently removable (delete extension method call + project reference)
- Solution file: `Starter.WebApi.slnx` (newer .slnx format)

**2. Quick Commands**
- Build: `dotnet build`
- Run: `dotnet run --project src/Starter.WebApi`
- Test all: `dotnet test`
- Test specific project: `dotnet test tests/Starter.WebApi.Tests.Unit`
- URLs: https://localhost:5101 (HTTPS), http://localhost:5100 (HTTP)
- API docs: https://localhost:5101/scalar/v1

**3. Architecture**
- Solution structure: Host (`Starter.WebApi`), Libraries (`Starter.Shared`), Modules (19 class libraries), Migrations (3 provider-specific), Tests (3 projects)
- Each module is a class library with a public static extension class (e.g., `CachingExtensions.cs` with `AddAppCaching()`)
- `Program.cs` is organized by concern sections: Bootstrap Logger, Observability, Security, Data, API, Production Hardening, Health, Middleware Pipeline
- Configuration via `appsettings.json` with `IOptions<T>`, `ValidateDataAnnotations`, `ValidateOnStart`

**4. Module Pattern (the key convention)**
Document the exact pattern for creating a new module:
- Create class library project targeting `net10.0` with `<FrameworkReference Include="Microsoft.AspNetCore.App" />`
- Create `{ModuleName}Extensions.cs` with public static extension methods on `WebApplicationBuilder`, `IServiceCollection`, or `WebApplication`
- Mark all other types `internal`
- Create `Options/{ModuleName}Options.cs` with `SectionName` constant for config binding
- Extension method naming: `AddApp{Feature}()` for service registration, `UseApp{Feature}()` for middleware
- Register in `Program.cs` under the appropriate concern section

**5. Coding Conventions**
- .NET 10, C# latest, nullable enabled, implicit usings enabled
- File-scoped namespaces (`namespace X;`)
- Primary constructors for DI (e.g., `public class TodoController(ITodoService todoService) : ControllerBase`)
- Controllers: `[ApiVersion]`, `[ApiController]`, `[Route("api/v{version:apiVersion}/...")]`, `[Authorize]`
- Validation: FluentValidation with manual `IValidator<T>` injection via `[FromServices]`, throw `AppValidationException` on failure
- Response envelope: opt-in via `[WrapResponse]` attribute on controller class
- Rate limiting: opt-in via `[EnableRateLimiting("policy")]` attribute
- XML doc comments on public APIs
- Contracts/interfaces in `Starter.Shared` (e.g., `ITodoService`)
- Internal by default, `public` only for extension methods and contracts

**6. Database**
- EF Core 10 with provider-switchable design (SQLite default, SqlServer, PostgreSQL)
- Separate migration assemblies per provider under `src/Starter.Data.Migrations.{Provider}/`
- Migration scripts in `scripts/` directory (add-migration.sh/.ps1, update-database.sh/.ps1)
- SQLite DB file: `starter.db` in host project (auto-created, gitignored)

**7. Testing Conventions**
- Integration: `WebApplicationFactory<Program>` in `Starter.WebApi.Tests.Integration`
- Unit: service-layer tests in `Starter.WebApi.Tests.Unit`
- Architecture: NetArchTest module isolation in `Starter.WebApi.Tests.Architecture`
- Architecture tests include 19-module removal smoke tests that verify any module can be removed without breaking the build
- Test framework: xUnit (standard .NET)

**8. Key Decisions to Honor**
- `AddIdentityCore` not `AddIdentity` (prevents cookie default override)
- `ApiResponseFilter` as opt-in `ServiceFilter`, not global middleware (preserves module removability)
- FluentValidation with manual injection, not the deprecated auto-validation pipeline
- Separate migration assemblies per DB provider (prevents migration conflicts)
- Internal by default visibility with `InternalsVisibleTo` only for test and cross-module EF access

**9. Do NOT**
- Add global middleware that would break module removability
- Use `AddIdentity()` — always `AddIdentityCore()`
- Make internal types public without good reason
- Add cross-module project references (modules should depend only on `Starter.Shared` or their own `*.Shared` project)
- Hardcode configuration values — use `IOptions<T>` with `appsettings.json` sections
- Commit secrets to `appsettings.json` — use User Secrets for development

Format: Use markdown headers, keep each section concise (not verbose). The file should be roughly 100-160 lines. This is a reference sheet, not documentation.
  </action>
  <verify>
    <automated>test -f F:/Personal/bootstrapper-apps/web-api/CLAUDE.md && wc -l F:/Personal/bootstrapper-apps/web-api/CLAUDE.md | awk '{if ($1 >= 80) print "PASS: " $1 " lines"; else print "FAIL: only " $1 " lines"}'</automated>
  </verify>
  <done>CLAUDE.md exists at repository root with 80+ lines covering project identity, commands, architecture, module pattern, coding conventions, database, testing, key decisions, and anti-patterns</done>
</task>

</tasks>

<verification>
- CLAUDE.md exists at repository root
- File is comprehensive but concise (80-160 lines)
- Covers all 9 sections listed in the task action
- Build command from the file works: `dotnet build` passes
- Test command from the file works: `dotnet test` passes
</verification>

<success_criteria>
- CLAUDE.md is created and provides actionable instructions for Claude Code
- A new Claude Code session opening this repo would understand the module pattern, conventions, and key decisions without additional exploration
</success_criteria>

<output>
After completion, create `.planning/quick/260319-ity-create-an-agent-instruction-file-for-cla/260319-ity-SUMMARY.md`
</output>
