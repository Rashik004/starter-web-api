# Starter.WebApi -- Agent Instructions

Modular .NET 10 Web API starter repo. Namespace root: `Starter.WebApi`.
Core value: every module is independently removable (delete extension method call + project reference).
Solution file: `Starter.WebApi.slnx` (newer .slnx format).

## Quick Commands

```bash
dotnet build                                         # Build solution
dotnet run --project src/Starter.WebApi              # Run application
dotnet test                                          # Run all tests
dotnet test tests/Starter.WebApi.Tests.Unit          # Run specific test project
```

- HTTPS: https://localhost:5101
- HTTP: http://localhost:5100
- API docs: https://localhost:5101/scalar/v1

## Architecture

**Solution structure:** Host (`Starter.WebApi`), Libraries (`Starter.Shared`), Modules (19 class libraries), Migrations (3 provider-specific), Tests (3 projects).

Each module is a class library with a public static extension class (e.g., `CachingExtensions.cs` with `AddAppCaching()`).

`Program.cs` is organized by concern sections: Bootstrap Logger, Observability, Security, Data, API, Production Hardening, Health, Middleware Pipeline.

Configuration via `appsettings.json` with `IOptions<T>`, `ValidateDataAnnotations`, `ValidateOnStart`.

## Module Pattern

This is the key convention. Every module follows this structure:

1. **Class library project** targeting `net10.0` with `<FrameworkReference Include="Microsoft.AspNetCore.App" />`
2. **`{ModuleName}Extensions.cs`** -- public static extension methods on `WebApplicationBuilder`, `IServiceCollection`, or `WebApplication`
3. **All other types `internal`** -- only extension methods and shared contracts are public
4. **`Options/{ModuleName}Options.cs`** -- options class with `SectionName` constant for config binding
5. **Extension method naming:** `AddApp{Feature}()` for service registration, `UseApp{Feature}()` for middleware
6. **Register in `Program.cs`** under the appropriate concern section

## Coding Conventions

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

## Database

- EF Core 10 with provider-switchable design (SQLite default, SqlServer, PostgreSQL)
- Separate migration assemblies per provider under `src/Starter.Data.Migrations.{Provider}/`
- Migration scripts in `scripts/` directory (`add-migration.sh`/`.ps1`, `update-database.sh`/`.ps1`)
- SQLite DB file: `starter.db` in host project (auto-created, gitignored)

## Testing Conventions

- **Integration:** `WebApplicationFactory<Program>` in `Starter.WebApi.Tests.Integration`
- **Unit:** service-layer tests in `Starter.WebApi.Tests.Unit`
- **Architecture:** NetArchTest module isolation in `Starter.WebApi.Tests.Architecture`
- Architecture tests include 19-module removal smoke tests verifying any module can be removed without breaking the build
- Test framework: xUnit

## Key Decisions to Honor

- `AddIdentityCore` not `AddIdentity` (prevents cookie default override)
- `ApiResponseFilter` as opt-in `ServiceFilter`, not global middleware (preserves module removability)
- FluentValidation with manual injection, not the deprecated auto-validation pipeline
- Separate migration assemblies per DB provider (prevents migration conflicts)
- Internal by default visibility with `InternalsVisibleTo` only for test and cross-module EF access

## Do NOT

- Add global middleware that would break module removability
- Use `AddIdentity()` -- always `AddIdentityCore()`
- Make internal types public without good reason
- Add cross-module project references (modules depend only on `Starter.Shared` or their own `*.Shared` project)
- Hardcode configuration values -- use `IOptions<T>` with `appsettings.json` sections
- Commit secrets to `appsettings.json` -- use User Secrets for development
