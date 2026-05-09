# Starter.WebApi

A modular .NET 10 Web API starter where every feature is independently removable.

## Core Value

Each feature is a self-contained class library registered via extension methods in `Program.cs`. Removing a feature is two steps:

1. Delete the extension method call(s) in `Program.cs`
2. Remove the project reference

No cascading breakage. The remaining modules continue to build and run without modification. This is verified by architecture tests and 19-module removal smoke tests.

## Features

### Observability

- **Structured logging** via Serilog with two-stage bootstrap (captures startup crashes)
- **Configurable sinks**: Console, File, Seq, OpenTelemetry (OTLP / Azure Application Insights)
- **Request logging** with correlation IDs, client IP, user agent enrichment
- All sink configuration driven entirely by `appsettings.json` -- no code changes to enable/disable

### Security

- **ASP.NET Identity** user/role/claim store backed by EF Core
- **JWT Bearer** token issuance and validation
- **Google OAuth** external authentication (no-op when credentials absent)
- **PolicyScheme** with `ForwardDefaultSelector` routing JWT vs cookie auth
- All three auth layers enabled by default; each independently removable

### Data

- **EF Core 10** with SQLite as the zero-config development default
- Swappable to **SQL Server** or **PostgreSQL** via configuration
- **Separate migration assemblies** per provider (no conflicts)
- **Repository pattern** wrapping DbContext
- Auto-migrate on startup (configurable)

### API Surface

- **OpenAPI 3.1** document generation with **Scalar** interactive API docs
- **API versioning** via URL segment (`/api/v1/`, `/api/v2/`) with sample controllers
- **FluentValidation** with RFC 7807 Problem Details integration
- **CORS** policies configurable via `appsettings.json` (dev/prod profiles)

### Production Hardening

- **Rate limiting**: fixed window, sliding window, and token bucket policies (global + per-endpoint)
- **Caching**: `IMemoryCache` + `IDistributedCache` (in-memory default, swappable to Redis)
- **Response compression**: Gzip/Brotli (opt-in, disabled by default for HTTPS security)
- **Standardized response envelope**: opt-in via `[WrapResponse]` attribute (not global middleware)

### Error Handling

- Global exception handler using `IExceptionHandler` returning RFC 7807 Problem Details
- Stack traces included in Development, hidden in Production

### Health Checks

- `/health` -- aggregate status
- `/health/ready` -- readiness probe
- `/health/live` -- liveness probe
- Database connectivity check and sample external service check included

### Testing

- **Integration tests** using `WebApplicationFactory<Program>`
- **Unit tests** with sample service-layer coverage
- **Architecture tests** enforcing module isolation via NetArchTest
- **Module removal smoke tests** proving all 19 modules can be independently removed

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download)

No `global.json` is included -- the project builds with any .NET 10+ SDK.

## Quick Start

This is a template repository. The fastest path from clone to running app is the bootstrap script -- it renames the project, trims to a single database provider, and provisions a JWT signing key in one command.

**PowerShell (Windows):**

```powershell
./scripts/init-project.ps1 -NewPrefix Acme -Provider Sqlite
```

**Bash (Linux/macOS):**

```bash
./scripts/init-project.sh --prefix Acme --provider Sqlite
```

That's it. After the script completes:

```bash
dotnet run --project src/Host/Acme.WebApi
```

The application starts at `https://localhost:5101` (HTTPS) or `http://localhost:5100` (HTTP). The interactive API documentation lives at `https://localhost:5101/scalar/v1` (v2 also available at `/scalar/v2`). The SQLite database (`acme.db`) is created and migrated automatically on first run.

If you skip the bootstrap and want to run the unrenamed template directly, you must set the JWT signing key manually first (otherwise the app fails `ValidateOnStart`):

```bash
dotnet user-secrets set "Jwt:SecretKey" "your-256-bit-secret-key-here-min-32-chars" \
  --project src/Host/Starter.WebApi
dotnet run --project src/Host/Starter.WebApi
```

## Bootstrap Script

`init-project` is a thin orchestrator that runs three steps in order:

1. **Rename** -- replaces the `Starter` prefix with your chosen prefix throughout namespaces, folders, files, project references, configuration values, and scripts.
2. **DB trim** -- removes the two unused migration projects, drops their EF Core packages, rewrites `DataExtensions.cs` and `DatabaseOptions.cs` for the chosen provider, and cleans `appsettings.json` connection strings.
3. **JWT key** -- generates a 48-byte base64 secret and stores it via `dotnet user-secrets`. Skip with `-NoJwtSecret` / `--no-jwt-secret`.

**Common options:**

| Parameter | Description |
|-----------|-------------|
| `-NewPrefix` / `--prefix` | New prefix (must be a valid C# identifier or dotted namespace, e.g. `Acme` or `Acme.Server`). Prompted if omitted. |
| `-Provider` / `--provider` | DB provider to keep: `Sqlite`, `SqlServer`, or `PostgreSql`. Prompted if omitted (default: `Sqlite`). |
| `-OldPrefix` / `--old-prefix` | Existing prefix to replace (default: `Starter`). |
| `-Force` / `--force` | Skip the dirty-tree pushback prompt. |
| `-SkipBuild` / `--skip-build` | Skip the verification build at each step. |
| `-NoBackupBranch` / `--no-backup-branch` | Skip the pre-trim git backup branch. |
| `-NoJwtSecret` / `--no-jwt-secret` | Don't auto-generate the JWT signing key (for CI). |
| `-IncludeBootstrapScripts` / `--include-bootstrap-scripts` | Rewrite the bootstrap scripts themselves. Default: skip them so the template stays reusable. |

After the script completes, review the staged diff with `git diff --cached` and commit when ready.

## Manual Flow (advanced)

If you want explicit control over each step, the underlying scripts run independently.

### Rename only

```powershell
./scripts/rename-project.ps1 -NewPrefix Acme
```

```bash
./scripts/rename-project.sh Acme
```

The script will:

1. Clean build artifacts (`bin/`, `obj/`, `.vs/`)
2. Replace `Starter` and `starter` in all source files (`.cs`, `.csproj`, `.slnx`, `.json`, `.ps1`, `.sh`, `.md`)
3. Rename `.csproj` files, project directories, and the `.slnx` solution file
4. Run a verification build to confirm everything compiles

After the rename, delete the old SQLite database if it exists (`starter.db`) and reopen your IDE to refresh caches.

**Rename options:**

| Parameter | Description |
|-----------|-------------|
| `-NewPrefix` / `$1` | New prefix name (required, must be a valid C# identifier) |
| `-OldPrefix` / `$2` | Previous prefix to replace (default: `Starter`, useful for re-renaming) |
| `-SkipBuild` / `--skip-build` | Skip the verification build after renaming |
| `-IncludeBootstrapScripts` / `--include-bootstrap-scripts` | Rewrite the bootstrap scripts themselves (default: leave them so the template stays reusable) |

### Trim DB provider only

The project defaults to SQLite for zero-configuration development. To standardize on SQL Server or PostgreSQL, the trim script removes the unused migration assemblies and updates all project references and configuration in one command. Re-running on an already-trimmed repo aborts with a clear message; pass `-Force` / `--force` to override.

```powershell
./scripts/select-db-provider.ps1 -Provider SqlServer
```

```bash
./scripts/select-db-provider.sh --provider SqlServer
```

The script will:

1. Create a backup git branch (unless `-NoBackupBranch` / `--no-backup-branch` is passed)
2. Remove the two unused migration projects from `src/Migrations/`
3. Update the `.slnx` solution file and host `.csproj`
4. Remove unused EF Core packages from `<Prefix>.Data.csproj`
5. Rewrite `DataExtensions.cs` with provider-specific configuration
6. Rewrite `DatabaseOptions.cs` (removing `MaxRetryCount` for SQLite)
7. Surgically clean `appsettings.json` files (preserves comments and formatting)
8. Delete the SQLite `.db` file if switching away from SQLite
9. Run a verification build to confirm everything compiles
10. Stage all changes (no commit)

**Trim options:**

| Parameter | Description |
|-----------|-------------|
| `-Provider` / `--provider` | Provider to keep: `Sqlite`, `SqlServer`, or `PostgreSql` (prompts if omitted, default `Sqlite`) |
| `-Prefix` / `--prefix` | Project namespace prefix (auto-detected if omitted, required if multiple `.slnx` files) |
| `-DryRun` / `--dry-run` | Print planned changes without mutating files |
| `-NoBackupBranch` / `--no-backup-branch` | Skip the automatic pre-trim backup branch |
| `-Force` / `--force` | Proceed even if git working tree is dirty, or if repo is already trimmed |
| `-SkipBuild` / `--skip-build` | Skip the verification build after trimming |

**Example (interactive):**

```powershell
./scripts/select-db-provider.ps1
# Select provider from menu (default: Sqlite)
```

**Example (SQL Server with dry-run):**

```bash
./scripts/select-db-provider.sh --provider SqlServer --dry-run
```

After the script completes, review the staged diff with `git diff --cached`, then commit when ready:

```bash
git commit -m "chore: trim DB providers to SqlServer"
```

## Project Structure

The solution uses the newer `.slnx` format (`Starter.WebApi.slnx`).

```
web-api/
|-- src/
|   |-- Starter.WebApi/                        # Host application (Program.cs, controllers)
|   |-- Starter.Shared/                        # Cross-module contracts (response envelope, interfaces)
|   |
|   |-- Starter.Auth.Shared/                   # PolicyScheme + ForwardDefaultSelector
|   |-- Starter.Auth.Identity/                 # ASP.NET Identity with EF Core stores
|   |-- Starter.Auth.Jwt/                      # JWT Bearer validation + token service
|   |-- Starter.Auth.Google/                   # Google OAuth external provider
|   |
|   |-- Starter.Data/                          # EF Core DbContext, repository pattern
|   |-- Starter.Data.Migrations.Sqlite/        # SQLite migration assembly
|   |-- Starter.Data.Migrations.SqlServer/     # SQL Server migration assembly
|   |-- Starter.Data.Migrations.PostgreSql/    # PostgreSQL migration assembly
|   |
|   |-- Starter.Logging/                       # Serilog pipeline + request logging
|   |-- Starter.ExceptionHandling/             # Global exception handler + Problem Details
|   |-- Starter.HealthChecks/                  # Health check registrations + endpoints
|   |
|   |-- Starter.OpenApi/                       # OpenAPI 3.1 + Scalar UI
|   |-- Starter.Versioning/                    # API versioning (URL segment)
|   |-- Starter.Validation/                    # FluentValidation integration
|   |-- Starter.Cors/                          # CORS policies from config
|   |
|   |-- Starter.RateLimiting/                  # Rate limiting policies from config
|   |-- Starter.Caching/                       # IMemoryCache + IDistributedCache
|   |-- Starter.Compression/                   # Gzip/Brotli response compression
|   |-- Starter.Responses/                     # Standardized response envelope filter
|
|-- tests/
|   |-- Starter.WebApi.Tests.Integration/      # WebApplicationFactory integration tests
|   |-- Starter.WebApi.Tests.Unit/             # Service-layer unit tests
|   |-- Starter.WebApi.Tests.Architecture/     # NetArchTest module isolation + removal smoke tests
|
|-- scripts/
|   |-- init-project.sh / .ps1               # One-shot bootstrap: rename + DB trim + JWT secret
|   |-- rename-project.sh / .ps1             # Rename project prefix (Starter -> YourName)
|   |-- select-db-provider.sh / .ps1         # Trim solution to a single DB provider
|   |-- add-migration.sh / .ps1              # EF Core migration helper
|   |-- update-database.sh / .ps1            # Database update helper
```

## Configuration

All runtime behavior is configured via `appsettings.json` using strongly-typed `IOptions<T>` bindings with `ValidateDataAnnotations` and `ValidateOnStart`. Misconfiguration is caught at startup, not at request time.

| Section | Purpose |
|---------|---------|
| `Database` | Provider selection (`Sqlite`, `SqlServer`, `PostgreSql`), auto-migrate, retry policy |
| `ConnectionStrings` | Connection strings keyed by provider name |
| `Jwt` | Signing key, issuer, audience, token lifetime |
| `Authentication:Google` | Google OAuth client credentials (optional) |
| `Cors` | Allowed origins, methods, headers, credentials |
| `OpenApi` | API doc title, description, Scalar toggle |
| `RateLimiting` | Global limits, fixed/sliding/token bucket policy parameters |
| `Caching` | Default expiration, sliding expiration, Redis connection |
| `Compression` | HTTPS compression toggle, Brotli/Gzip compression levels |
| `HealthChecks` | External service URI, timeout |
| `Serilog` | Minimum levels, enrichers, sink configuration (Console, File, Seq, OpenTelemetry) |
| `ExceptionHandling` | Stack trace visibility in development |

See `src/Starter.WebApi/appsettings.json` for the full configuration with inline documentation.

## Database Providers

The default provider is SQLite with zero configuration. To switch providers:

1. Set `Database:Provider` in `appsettings.json` to `Sqlite`, `SqlServer`, or `PostgreSql`
2. Update the corresponding connection string in `ConnectionStrings`
3. Run `dotnet run` -- auto-migrate applies pending migrations on startup

```json
{
  "Database": {
    "Provider": "SqlServer"
  },
  "ConnectionStrings": {
    "SqlServer": "Server=myserver;Database=MyDb;Trusted_Connection=True;"
  }
}
```

Migration helper scripts are provided in the `scripts/` directory:

```bash
# Add a new migration
./scripts/add-migration.sh MigrationName

# Update the database manually
./scripts/update-database.sh
```

Each provider has its own migration assembly (`Starter.Data.Migrations.Sqlite`, `.SqlServer`, `.PostgreSql`), so migrations for different providers never conflict.

## Adding and Removing Modules

This is the key differentiator. Every module follows the same pattern for removal.

### Example: Removing Google OAuth

1. In `src/Starter.WebApi/Program.cs`, delete the extension method call:

```csharp
// Delete this line:
builder.AddAppGoogle();        // Google OAuth (no-op when credentials absent)
```

2. Remove the project reference from `src/Starter.WebApi/Starter.WebApi.csproj`:

```xml
<!-- Delete this line: -->
<ProjectReference Include="..\Starter.Auth.Google\Starter.Auth.Google.csproj" />
```

3. Remove the using directive from `Program.cs`:

```csharp
// Delete this line:
using Starter.Auth.Google;
```

4. Build and run:

```bash
dotnet build   # Succeeds
dotnet run --project src/Starter.WebApi   # Runs without Google auth
```

All modules follow this same pattern. No other files need modification.

## Module Reference

| Module | Extension Method(s) | Config Section |
|--------|---------------------|----------------|
| Starter.Auth.Shared | `AddAppAuthShared()` | -- |
| Starter.Auth.Identity | `AddAppIdentity()` | -- |
| Starter.Auth.Jwt | `AddAppJwt()` | `Jwt` |
| Starter.Auth.Google | `AddAppGoogle()` | `Authentication:Google` |
| Starter.Caching | `AddAppCaching()` | `Caching` |
| Starter.Compression | `AddAppCompression()` / `UseAppCompression()` | `Compression` |
| Starter.Cors | `AddAppCors()` | `Cors` |
| Starter.Data | `AddAppData()` / `UseAppData()` | `Database`, `ConnectionStrings` |
| Starter.Data.Migrations.Sqlite | -- | `ConnectionStrings` |
| Starter.Data.Migrations.SqlServer | -- | `ConnectionStrings` |
| Starter.Data.Migrations.PostgreSql | -- | `ConnectionStrings` |
| Starter.ExceptionHandling | `AddAppExceptionHandling()` / `UseAppExceptionHandling()` | `ExceptionHandling` |
| Starter.HealthChecks | `AddAppHealthChecks()` / `UseAppHealthChecks()` | `HealthChecks` |
| Starter.Logging | `AddAppLogging()` / `UseAppRequestLogging()` | `Serilog` |
| Starter.OpenApi | `AddAppOpenApi()` / `UseAppOpenApi()` | `OpenApi` |
| Starter.RateLimiting | `AddAppRateLimiting()` / `UseAppRateLimiting()` | `RateLimiting` |
| Starter.Responses | `AddAppResponses()` | -- |
| Starter.Validation | `AddAppValidation()` | -- |
| Starter.Versioning | `AddAppVersioning()` | -- |

**Note:** Modules without a config section are zero-configuration. Modules with `Use*()` methods register middleware in the HTTP pipeline. Migration assemblies are provider-specific and have no extension methods. Compression is opt-in -- uncomment in `Program.cs` to enable.

## Running Tests

```bash
# Run all tests from the solution root
dotnet test
```

| Test Project | Coverage |
|-------------|----------|
| `Starter.WebApi.Tests.Integration` | Health checks, auth flows, CRUD operations via `WebApplicationFactory` |
| `Starter.WebApi.Tests.Unit` | Service-layer logic, validators, isolated component tests |
| `Starter.WebApi.Tests.Architecture` | Module isolation enforcement (NetArchTest), 19-module removal smoke tests |

## Configuration Secrets

**Development** -- Use .NET User Secrets (never committed to source control):

```bash
dotnet user-secrets set "Jwt:SecretKey" "your-256-bit-secret-key-here-min-32-chars" \
  --project src/Starter.WebApi

dotnet user-secrets set "Authentication:Google:ClientId" "your-client-id" \
  --project src/Starter.WebApi
```

**Environment Variables** -- Use double-underscore for nested keys:

```bash
export Jwt__SecretKey="your-secret-key"
export Authentication__Google__ClientId="your-client-id"
export Caching__RedisConnectionString="localhost:6379"
```

**Production** -- Use Azure Key Vault or environment variables. Never commit secrets to `appsettings.json`.

See the comments in `src/Starter.WebApi/appsettings.json` for per-section guidance.

## License

[MIT](LICENSE)
