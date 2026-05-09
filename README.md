# Starter.WebApi

Modular .NET 10 Web API starter. Every module is independently removable — delete the extension call and project reference, nothing else breaks. Verified by architecture tests.

## Quick Start

Prerequisite: [.NET 10 SDK](https://dotnet.microsoft.com/download). No `global.json` — any 10+ SDK works.

```powershell
# Windows
./scripts/init-project.ps1 -NewPrefix Acme -Provider Sqlite
dotnet run --project src/Host/Acme.WebApi
```

```bash
# Linux/macOS
./scripts/init-project.sh --prefix Acme --provider Sqlite
dotnet run --project src/Host/Acme.WebApi
```

The bootstrap script renames the project, trims to one DB provider, and provisions a JWT signing key. SQLite DB auto-creates on first run.

- HTTPS: <https://localhost:5101>
- HTTP: <http://localhost:5100>
- API docs: <https://localhost:5101/scalar/v1>

First-run on macOS/Linux: `dotnet dev-certs https --trust`. Port conflict? Edit `src/Host/<Prefix>.WebApi/Properties/launchSettings.json`.

## Try It

Register, get a JWT, call a protected endpoint:

```bash
# Register (auto-issues token)
TOKEN=$(curl -sk -X POST https://localhost:5101/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"me@example.com","password":"P@ssw0rd!"}' \
  | jq -r .accessToken)

# Create a todo
curl -sk -X POST https://localhost:5101/api/v1/todos \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"first todo"}'

# List todos
curl -sk https://localhost:5101/api/v1/todos -H "Authorization: Bearer $TOKEN"
```

Auth endpoints: `POST /api/auth/{register,login}`, `GET /api/auth/google`. Sample CRUD: `/api/v1/todos`, `/api/v2/todos`.

## Features

| Area | Included |
|------|----------|
| Observability | Serilog two-stage bootstrap, request logging with correlation IDs, sinks: Console / File / Seq / OTLP / App Insights |
| Auth | ASP.NET Identity (EF Core stores), JWT Bearer, Google OAuth, PolicyScheme `ForwardDefaultSelector` |
| Data | EF Core 10, swappable SQLite / SqlServer / PostgreSQL, separate migration assemblies, repository pattern, auto-migrate |
| API | OpenAPI 3.1 + Scalar UI, URL-segment versioning, FluentValidation → RFC 7807, configurable CORS |
| Hardening | Rate limiting (fixed/sliding/token bucket), `IMemoryCache` + `IDistributedCache` (Redis-ready), Gzip/Brotli compression (opt-in), `[WrapResponse]` envelope (opt-in) |
| Errors | `IExceptionHandler` → Problem Details, stack traces gated by environment |
| Health | `/health`, `/health/ready`, `/health/live` with DB + external-service checks |
| Tests | xUnit. Integration (`WebApplicationFactory`), Unit (services), Architecture (NetArchTest + 19-module removal smoke tests) |

## Project Layout

```
src/
├── Host/<Prefix>.WebApi/          # Program.cs, controllers, appsettings.json
├── Libraries/<Prefix>.Shared/     # Cross-module contracts
├── Modules/<Prefix>.*             # 16 removable feature modules
├── Migrations/<Prefix>.Data.Migrations.{Sqlite,SqlServer,PostgreSql}
└── tests/<Prefix>.WebApi.Tests.{Unit,Integration,Architecture}
```

Solution file: `<Prefix>.WebApi.slnx` (newer `.slnx` format).

## Module Pattern

Each module is a class library with one public extension class. Adding/removing a module = three edits:

```csharp
// 1. Program.cs — drop the registration
builder.AddAppGoogle();              // delete

// 2. Program.cs — drop the using
using Starter.Auth.Google;           // delete

// 3. <Prefix>.WebApi.csproj — drop the ProjectReference
<ProjectReference Include="..\..\Modules\Starter.Auth.Google\Starter.Auth.Google.csproj" />
```

`dotnet build` succeeds. No other files touched. Same pattern for all 16 modules.

## Module Reference

| Module | Extension | Config Section |
|--------|-----------|----------------|
| Auth.Shared | `AddAppAuthShared()` | — |
| Auth.Identity | `AddAppIdentity()` | — |
| Auth.Jwt | `AddAppJwt()` | `Jwt` |
| Auth.Google | `AddAppGoogle()` | `Authentication:Google` |
| Caching | `AddAppCaching()` | `Caching` |
| Compression | `AddAppCompression()` / `UseAppCompression()` | `Compression` |
| Cors | `AddAppCors()` | `Cors` |
| Data | `AddAppData()` / `UseAppData()` | `Database`, `ConnectionStrings` |
| ExceptionHandling | `AddAppExceptionHandling()` / `UseAppExceptionHandling()` | `ExceptionHandling` |
| HealthChecks | `AddAppHealthChecks()` / `UseAppHealthChecks()` | `HealthChecks` |
| Logging | `AddAppLogging()` / `UseAppRequestLogging()` | `Serilog` |
| OpenApi | `AddAppOpenApi()` / `UseAppOpenApi()` | `OpenApi` |
| RateLimiting | `AddAppRateLimiting()` / `UseAppRateLimiting()` | `RateLimiting` |
| Responses | `AddAppResponses()` | — |
| Validation | `AddAppValidation()` | — |
| Versioning | `AddAppVersioning()` | — |

Compression is registered but commented out in `Program.cs` — uncomment to enable.

## Configuration

All sections bound via `IOptions<T>` with `ValidateDataAnnotations` + `ValidateOnStart`. Misconfig fails at startup.

| Section | Purpose |
|---------|---------|
| `Database` / `ConnectionStrings` | Provider, auto-migrate, retry policy, connection strings |
| `Jwt` | Signing key, issuer, audience, lifetime |
| `Authentication:Google` | OAuth client credentials (optional) |
| `Cors` | Origins, methods, headers, credentials |
| `OpenApi` | Title, description, Scalar toggle |
| `RateLimiting` | Global + per-policy parameters |
| `Caching` | Expiration, Redis connection |
| `Compression` | HTTPS toggle, Brotli/Gzip levels |
| `HealthChecks` | External service URI, timeout |
| `Serilog` | Levels, enrichers, sinks |
| `ExceptionHandling` | Stack trace visibility |

Inline docs in `src/Host/<Prefix>.WebApi/appsettings.json`.

## Database Providers

Default: SQLite, zero config. Switch via `Database:Provider` = `Sqlite` | `SqlServer` | `PostgreSql` and matching `ConnectionStrings` entry. Auto-migrate runs on startup.

```bash
./scripts/add-migration.sh MigrationName
./scripts/update-database.sh
```

## Tests

```bash
dotnet test
```

| Project | Coverage |
|---------|----------|
| `Tests.Integration` | `WebApplicationFactory` — health, auth, CRUD |
| `Tests.Unit` | Services, validators |
| `Tests.Architecture` | Module isolation + 19-module removal smoke tests |

## Secrets

Dev: `dotnet user-secrets`. Env vars: double-underscore for nested keys (`Jwt__SecretKey`). Prod: Key Vault or env vars. Never in `appsettings.json`.

## Advanced

Each bootstrap step runs standalone:

- `rename-project.{sh,ps1}` — rename prefix only
- `select-db-provider.{sh,ps1}` — trim to one DB provider (supports `--dry-run`, `--force`)
- `reset-project.{sh,ps1}` — undo bootstrap
- `smoke-test.{sh,ps1}` — verify build after changes

Run with `--help` / `-?` for full options. CI usage: pass `--no-jwt-secret` and `--skip-build` to `init-project`.

## License

[MIT](LICENSE)
