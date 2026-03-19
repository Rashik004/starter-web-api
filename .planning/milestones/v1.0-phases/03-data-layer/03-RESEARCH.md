# Phase 3: Data Layer - Research

**Researched:** 2026-03-18
**Domain:** EF Core 10 multi-provider data layer with SQLite, SQL Server, PostgreSQL
**Confidence:** HIGH

## Summary

EF Core 10 (version 10.0.5, stable) ships with .NET 10 and provides first-class support for the multi-provider separate-migration-assembly pattern documented in the official Microsoft docs. The project targets `net10.0` and uses SDK 10.0.101, so all EF Core 10 packages are fully compatible. The recommended architecture uses a single `AppDbContext` in `Starter.Data` with three separate migration class libraries, each containing only migration files and a marker type for assembly resolution. Provider switching at runtime is controlled by a `Database:Provider` configuration key that selects the provider and matching connection string in a `switch` expression during `AddDbContext` registration.

The user's global `dotnet-ef` tool is currently at version 8.0.6 and **must be upgraded to 10.x** before any migration commands will work with the .NET 10 project. EF Core 10 has a breaking change requiring `--framework` when projects multi-target, but since all projects in this solution use single `<TargetFramework>net10.0</TargetFramework>`, this does not apply. The SQLite provider has breaking changes around `DateTimeOffset`/`DateTime` timezone handling (now assumes UTC), which matters for the `CreatedAt` property on `TodoItem`.

**Primary recommendation:** Use the official Microsoft "one context type, separate migration assemblies" pattern with `MigrationsAssembly()` per provider, marker interfaces for assembly name resolution, and `HasData()` for initial seed data (static, deterministic, small -- ideal for HasData). Use `UseSeeding`/`UseAsyncSeeding` for more complex runtime seeding if needed later.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- String-based provider name in `Database:Provider` key with values `Sqlite`, `SqlServer`, `PostgreSql`
- All three connection strings pre-populated in appsettings.json -- SQLite has a working default, SQL Server and PostgreSQL have placeholder values
- Invalid provider name causes immediate startup failure via ValidateOnStart (no silent fallback)
- Config section includes common EF options: CommandTimeout, EnableSensitiveDataLogging, MaxRetryCount (appsettings-driven)
- TodoItem entity (Id, Title, IsComplete, CreatedAt) as the sample -- simple, universally understood, easy to delete
- Generic `IRepository<T>` interface in Starter.Shared, concrete `EfRepository<T>` in Starter.Data (internal)
- Full service layer: Controller -> ITodoService -> IRepository<TodoItem>
- Entity (TodoItem) lives in Starter.Data, not Shared -- only interfaces (IRepository<T>, ITodoService) live in Shared
- Controllers work with DTOs/interface return types, not EF entity types directly
- Separate migration projects per provider: `Starter.Data.Migrations.Sqlite`, `Starter.Data.Migrations.SqlServer`, `Starter.Data.Migrations.PostgreSql`
- Shell scripts (bash + PowerShell) wrap `dotnet ef` with correct `--project` and `--startup-project` flags per provider
- Scripts live in `scripts/` directory: `add-migration.sh/.ps1`, `update-database.sh/.ps1`
- Auto-migration on startup controlled by `Database:AutoMigrate` config flag -- works in any environment (user's responsibility to disable in production)
- Initial seed migration includes sample TodoItems via `HasData()` for immediate verification
- Single `AppDbContext` in Starter.Data owns all entity configurations
- Phase 4 Identity will add its entities to the same context -- no separate IdentityDbContext
- Extensibility via `IEntityTypeConfiguration` with assembly scanning (`ApplyConfigurationsFromAssembly()`) -- Phase 4 Auth module provides its own configurations that get discovered automatically
- Starter.Data references Starter.Shared for IRepository<T> and shared exception types (NotFoundException, etc.)
- No module-to-module references -- Starter.Data does not reference Starter.Auth (or vice versa for data access)

### Claude's Discretion
- EF Core configuration details (retry policies, connection resiliency specifics)
- Exact DTO shape for TodoItem API responses
- TodoService implementation details (validation, business rules)
- Seed data content (specific sample TodoItems)
- Script implementation details (argument parsing, error messages)
- Whether to include EF Core interceptors or query filters

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DATA-01 | EF Core 10 is configured with SQLite as the zero-config development default | Verified EF Core 10.0.5 stable + SQLite provider 10.0.5; `UseSqlite()` with `Data Source=starter.db` requires no external server; auto-migrate on startup creates DB file automatically |
| DATA-02 | SQL Server provider is available and swappable via configuration | `Microsoft.EntityFrameworkCore.SqlServer` 10.0.5 verified; `UseSqlServer()` with `MigrationsAssembly()` per official multi-provider docs; `EnableRetryOnFailure()` available |
| DATA-03 | PostgreSQL provider is available and swappable via configuration | `Npgsql.EntityFrameworkCore.PostgreSQL` 10.0.1 verified; `UseNpgsql()` with `MigrationsAssembly()` + `EnableRetryOnFailure()` available via NpgsqlRetryingExecutionStrategy |
| DATA-04 | Separate migration assemblies exist per database provider | Official Microsoft pattern: one DbContext + 3 migration class libraries with marker types; `MigrationsAssembly()` configured per provider in switch expression |
| DATA-05 | Migration helper scripts are provided (dotnet ef migrations add / database update) | Scripts wrap `dotnet ef` with `--startup-project`, `--project`, and `-- --provider` arg forwarding; dotnet-ef tool must be upgraded from 8.0.6 to 10.x |
| DATA-06 | A repository pattern or thin service layer wraps DbContext | Generic `IRepository<T>` in Shared, `EfRepository<T>` internal in Data; `ITodoService` in Shared, `TodoService` internal in Data; Controller uses DTOs |

</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Microsoft.EntityFrameworkCore | 10.0.5 | ORM framework | Ships with .NET 10 LTS, first-class multi-provider support |
| Microsoft.EntityFrameworkCore.Sqlite | 10.0.5 | SQLite database provider | Zero-config dev default, file-based DB |
| Microsoft.EntityFrameworkCore.SqlServer | 10.0.5 | SQL Server database provider | Enterprise production database |
| Npgsql.EntityFrameworkCore.PostgreSQL | 10.0.1 | PostgreSQL database provider | Open-source production database |
| Microsoft.EntityFrameworkCore.Design | 10.0.5 | Design-time migration tooling | Required by `dotnet ef` CLI for scaffold/migration generation |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dotnet-ef (global tool) | 10.0.5 | CLI tool for migrations | Must match EF Core major version; currently 8.0.6, needs upgrade |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Separate migration assemblies | Output directory per provider (`--output-dir`) | Simpler setup but migrations share same assembly; conflicts when both providers are referenced simultaneously |
| Single DbContext + provider switch | Multiple DbContext subclasses per provider | Cleaner separation per provider but duplicates DbSet declarations and entity config; harder to maintain |
| HasData seed | UseSeeding/UseAsyncSeeding (EF9+) | UseSeeding is more flexible for runtime data, but HasData is ideal for small, static, deterministic seed data that should be migration-tracked |
| Generic IRepository<T> | Direct DbContext injection | Simpler but couples controllers to EF; user decision locks repository pattern |

**Installation (Starter.Data project):**
```bash
dotnet add src/Starter.Data/Starter.Data.csproj package Microsoft.EntityFrameworkCore --version 10.0.5
dotnet add src/Starter.Data/Starter.Data.csproj package Microsoft.EntityFrameworkCore.Sqlite --version 10.0.5
dotnet add src/Starter.Data/Starter.Data.csproj package Microsoft.EntityFrameworkCore.SqlServer --version 10.0.5
dotnet add src/Starter.Data/Starter.Data.csproj package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.1
dotnet add src/Starter.Data/Starter.Data.csproj package Microsoft.EntityFrameworkCore.Design --version 10.0.5
```

**Migration assembly projects (each one references Starter.Data and its provider):**
```bash
# Starter.Data.Migrations.Sqlite
dotnet add package Microsoft.EntityFrameworkCore.Sqlite --version 10.0.5

# Starter.Data.Migrations.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.SqlServer --version 10.0.5

# Starter.Data.Migrations.PostgreSql
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.1
```

**Tool upgrade (REQUIRED before any migrations work):**
```bash
dotnet tool update --global dotnet-ef --version 10.0.5
```

## Architecture Patterns

### Recommended Project Structure

```
src/
  Starter.Shared/
    Contracts/
      IRepository.cs           # Generic IRepository<T> interface
      ITodoService.cs          # Todo service contract
    Exceptions/
      NotFoundException.cs     # (already exists)
      ...
  Starter.Data/
    Entities/
      TodoItem.cs              # Entity class (internal to Data)
    Configuration/
      TodoItemConfiguration.cs # IEntityTypeConfiguration<TodoItem>
    Repositories/
      EfRepository.cs          # Generic EfRepository<T> (internal)
    Services/
      TodoService.cs           # ITodoService implementation (internal)
    Options/
      DatabaseOptions.cs       # IOptions<T> config with ValidateOnStart
    DataExtensions.cs          # AddAppData() extension method (public)
    AppDbContext.cs             # Single DbContext
  Starter.Data.Migrations.Sqlite/
    Marker.cs                  # Assembly marker for resolution
    Migrations/                # Generated migration files
  Starter.Data.Migrations.SqlServer/
    Marker.cs                  # Assembly marker for resolution
    Migrations/                # Generated migration files
  Starter.Data.Migrations.PostgreSql/
    Marker.cs                  # Assembly marker for resolution
    Migrations/                # Generated migration files
  Starter.WebApi/
    Controllers/
      TodoController.cs        # CRUD API using ITodoService + DTOs
    Models/
      TodoItemDto.cs           # DTO for API responses
      CreateTodoRequest.cs     # DTO for creation
      UpdateTodoRequest.cs     # DTO for updates
scripts/
  add-migration.sh             # Bash wrapper for dotnet ef migrations add
  add-migration.ps1            # PowerShell wrapper
  update-database.sh           # Bash wrapper for dotnet ef database update
  update-database.ps1          # PowerShell wrapper
```

### Pattern 1: Provider Switch via Configuration

**What:** Runtime provider selection using a switch expression in `AddDbContext` registration.
**When to use:** Always -- this is the core mechanism for multi-provider support.
**Example:**
```csharp
// Source: https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/providers
public static WebApplicationBuilder AddAppData(this WebApplicationBuilder builder)
{
    builder.Services.AddOptions<DatabaseOptions>()
        .BindConfiguration(DatabaseOptions.SectionName)
        .ValidateDataAnnotations()
        .ValidateOnStart();

    var dbOptions = builder.Configuration
        .GetSection(DatabaseOptions.SectionName)
        .Get<DatabaseOptions>()!;

    builder.Services.AddDbContext<AppDbContext>((sp, options) =>
    {
        _ = dbOptions.Provider switch
        {
            "Sqlite" => options.UseSqlite(
                builder.Configuration.GetConnectionString("Sqlite"),
                x => x.MigrationsAssembly(
                    typeof(Starter.Data.Migrations.Sqlite.Marker).Assembly.GetName().Name)),

            "SqlServer" => options.UseSqlServer(
                builder.Configuration.GetConnectionString("SqlServer"),
                x =>
                {
                    x.MigrationsAssembly(
                        typeof(Starter.Data.Migrations.SqlServer.Marker).Assembly.GetName().Name);
                    x.EnableRetryOnFailure(
                        maxRetryCount: dbOptions.MaxRetryCount,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                }),

            "PostgreSql" => options.UseNpgsql(
                builder.Configuration.GetConnectionString("PostgreSql"),
                x =>
                {
                    x.MigrationsAssembly(
                        typeof(Starter.Data.Migrations.PostgreSql.Marker).Assembly.GetName().Name);
                    x.EnableRetryOnFailure(
                        maxRetryCount: dbOptions.MaxRetryCount,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorCodesToAdd: null);
                }),

            _ => throw new InvalidOperationException(
                $"Unsupported database provider: {dbOptions.Provider}. " +
                "Valid values: Sqlite, SqlServer, PostgreSql")
        };

        if (dbOptions.CommandTimeout > 0)
            options.SetCommandTimeout(dbOptions.CommandTimeout);

        if (dbOptions.EnableSensitiveDataLogging)
            options.EnableSensitiveDataLogging();
    });

    // Register repository and services
    builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
    builder.Services.AddScoped<ITodoService, TodoService>();

    return builder;
}
```

### Pattern 2: IEntityTypeConfiguration with Assembly Scanning

**What:** Entity configurations as separate classes discovered via `ApplyConfigurationsFromAssembly`.
**When to use:** All entity configuration -- keeps AppDbContext clean and extensible for Phase 4.
**Example:**
```csharp
// Source: https://learn.microsoft.com/en-us/ef/core/modeling/
internal class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<TodoItem> TodoItems => Set<TodoItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        // Discovers all IEntityTypeConfiguration<T> in this assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

### Pattern 3: DatabaseOptions with ValidateOnStart

**What:** Strongly-typed configuration following existing project IOptions pattern.
**When to use:** All module configuration -- matches ExceptionHandling and Logging patterns.
**Example:**
```csharp
// Follows ExceptionHandlingOptions pattern from Phase 1
internal sealed class DatabaseOptions
{
    public const string SectionName = "Database";

    [Required]
    public string Provider { get; set; } = "Sqlite";

    public bool AutoMigrate { get; set; } = true;
    public int CommandTimeout { get; set; }
    public bool EnableSensitiveDataLogging { get; set; }
    public int MaxRetryCount { get; set; } = 3;
}
```

### Pattern 4: Auto-Migration on Startup

**What:** Conditionally apply pending migrations during application startup.
**When to use:** When `Database:AutoMigrate` is true in configuration.
**Example:**
```csharp
public static WebApplication UseAppData(this WebApplication app)
{
    var options = app.Configuration
        .GetSection(DatabaseOptions.SectionName)
        .Get<DatabaseOptions>();

    if (options?.AutoMigrate == true)
    {
        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.Migrate();
    }

    return app;
}
```

### Pattern 5: Marker Types for Migration Assembly Resolution

**What:** Empty public classes in each migration assembly used for `typeof().Assembly` resolution.
**When to use:** All migration assemblies -- avoids fragile string-based assembly names.
**Example:**
```csharp
// In Starter.Data.Migrations.Sqlite/Marker.cs
namespace Starter.Data.Migrations.Sqlite;

/// <summary>
/// Assembly marker for SQLite migration assembly resolution.
/// Used by DataExtensions to locate the correct migration assembly via typeof(Marker).Assembly.
/// </summary>
public sealed class Marker;
```

### Anti-Patterns to Avoid

- **Do NOT put entities in Starter.Shared:** Only interfaces and contracts go in Shared. Entity types live in Starter.Data to keep the data layer encapsulated.
- **Do NOT use OnConfiguring in AppDbContext:** All provider configuration happens in `AddAppData()` via DI. OnConfiguring is reserved for design-time factories only.
- **Do NOT create separate IdentityDbContext in Phase 4:** The context decision is locked -- Phase 4 adds Identity entities to the same AppDbContext.
- **Do NOT use `EnsureCreated()` alongside Migrations:** EnsureCreated does not use migrations and will conflict. Use `Database.Migrate()` exclusively.
- **Do NOT make EfRepository<T> public:** It is internal; only `IRepository<T>` is public (in Shared).
- **Do NOT reference migration assemblies from Starter.Data:** The reference goes the other direction -- migration projects reference Starter.Data.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Provider-specific migration isolation | Custom file-based migration routing | Separate class library projects + `MigrationsAssembly()` | Official EF Core pattern, handles snapshot isolation per provider automatically |
| Connection retry logic | Custom retry loops around SaveChanges | `EnableRetryOnFailure()` on SqlServer/Npgsql providers | Handles transient error detection, exponential backoff, and provider-specific error codes |
| Entity configuration discovery | Manual `modelBuilder.Entity<T>()` calls in OnModelCreating | `ApplyConfigurationsFromAssembly()` | Auto-discovers new configurations when Phase 4 Identity adds entity configs |
| Migration CLI argument handling | Manual `IDesignTimeDbContextFactory` per provider | Pass `--provider` via `--` arg forwarding to the host app | Simpler than factory classes; host app already has provider switching logic |
| Seed data management | Custom startup code to insert data | `HasData()` in entity configuration | Migration-tracked, deterministic, version-controlled; ideal for small static seed data |

**Key insight:** The `MigrationsAssembly()` + marker type pattern is the official Microsoft recommended approach for multi-provider scenarios. It handles the hard part -- keeping migration snapshots separate per provider -- which is impossible to replicate correctly with a hand-rolled solution.

## Common Pitfalls

### Pitfall 1: dotnet-ef Tool Version Mismatch
**What goes wrong:** `dotnet ef migrations add` fails with cryptic errors about missing types or incompatible assemblies.
**Why it happens:** The global `dotnet-ef` tool is at 8.0.6 but the project uses EF Core 10.0.5. EF tools must match the major version.
**How to avoid:** Run `dotnet tool update --global dotnet-ef --version 10.0.5` before any migration work.
**Warning signs:** Errors mentioning `Microsoft.EntityFrameworkCore.Design` version mismatch.

### Pitfall 2: Missing Microsoft.EntityFrameworkCore.Design Package
**What goes wrong:** `dotnet ef` cannot find the DbContext or fails during migration scaffolding.
**Why it happens:** `Microsoft.EntityFrameworkCore.Design` must be referenced as a package (not just a tool) in the startup project or the DbContext project.
**How to avoid:** Add `Microsoft.EntityFrameworkCore.Design` to the Starter.Data project. It should be a private asset (not transitive).
**Warning signs:** "Unable to create an object of type 'AppDbContext'" errors.

### Pitfall 3: SQLite DateTime/DateTimeOffset UTC Breaking Change
**What goes wrong:** `CreatedAt` timestamps behave differently than expected; `GetDateTimeOffset` without offset now assumes UTC.
**Why it happens:** EF Core 10 / Microsoft.Data.Sqlite 10 changed timezone handling -- timestamps without offset are treated as UTC, not local time.
**How to avoid:** Use `DateTime.UtcNow` consistently for the `CreatedAt` property. Avoid `DateTimeOffset` with SQLite unless explicitly handling offsets.
**Warning signs:** Timestamps off by the local timezone offset.

### Pitfall 4: Migration Assembly Not Found
**What goes wrong:** Runtime exception "No migrations assembly found" or migrations applied to wrong provider.
**Why it happens:** `MigrationsAssembly()` string doesn't match the actual assembly name, or the migration project isn't referenced from the startup project.
**How to avoid:** Use `typeof(Marker).Assembly.GetName().Name` instead of hardcoded strings. Ensure Host project has `<ProjectReference>` to all three migration assemblies.
**Warning signs:** Migrations work for one provider but fail silently for another.

### Pitfall 5: HasData Requires Explicit Primary Key Values
**What goes wrong:** `HasData()` call fails or migration generates incorrect SQL.
**Why it happens:** HasData requires explicit PK values even for auto-increment columns. It uses the PK to detect data changes between migrations.
**How to avoid:** Always specify `Id` values in `HasData()` calls: `new TodoItem { Id = 1, Title = "...", ... }`.
**Warning signs:** "The seed entity for entity type 'TodoItem' cannot be added because no value was provided for the required property 'Id'" error.

### Pitfall 6: EnableRetryOnFailure Not Available for SQLite
**What goes wrong:** Attempting to call `EnableRetryOnFailure()` on SQLite provider fails to compile.
**Why it happens:** SQLite does not have a built-in retry execution strategy like SQL Server and PostgreSQL do. SQLite is a local file-based database that doesn't experience transient network failures.
**How to avoid:** Only configure `EnableRetryOnFailure()` for SqlServer and PostgreSql providers. Skip it for Sqlite in the provider switch. The `MaxRetryCount` config option applies only to network-based providers.
**Warning signs:** Compilation error when trying to use retry on SQLite options builder.

### Pitfall 7: ApplyConfigurationsFromAssembly Scope
**What goes wrong:** Phase 4 Identity configurations aren't discovered by AppDbContext.
**Why it happens:** `ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly)` only scans the Starter.Data assembly. Phase 4 configurations in a different assembly won't be found.
**How to avoid:** Plan for Phase 4 to either: (a) add its configurations to Starter.Data directly, or (b) call `ApplyConfigurationsFromAssembly()` for additional assemblies. The CONTEXT.md says Phase 4 provides configurations "that get discovered automatically" -- this works if Phase 4 adds an additional `ApplyConfigurationsFromAssembly()` call.
**Warning signs:** Identity tables not created after migration despite configurations existing.

## Code Examples

Verified patterns from official sources:

### IRepository<T> Interface (Starter.Shared)
```csharp
// Follows project convention: public interface in Shared, internal implementation in Data
namespace Starter.Shared.Contracts;

public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<T> AddAsync(T entity, CancellationToken cancellationToken = default);
    Task UpdateAsync(T entity, CancellationToken cancellationToken = default);
    Task DeleteAsync(T entity, CancellationToken cancellationToken = default);
}
```

### EfRepository<T> Implementation (Starter.Data)
```csharp
// Internal -- only exposed via IRepository<T> through DI
namespace Starter.Data.Repositories;

internal sealed class EfRepository<T>(AppDbContext context) : IRepository<T>
    where T : class
{
    private readonly DbSet<T> _dbSet = context.Set<T>();

    public async Task<T?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
        => await _dbSet.FindAsync([id], cancellationToken);

    public async Task<IReadOnlyList<T>> GetAllAsync(CancellationToken cancellationToken = default)
        => await _dbSet.ToListAsync(cancellationToken);

    public async Task<T> AddAsync(T entity, CancellationToken cancellationToken = default)
    {
        await _dbSet.AddAsync(entity, cancellationToken);
        await context.SaveChangesAsync(cancellationToken);
        return entity;
    }

    public async Task UpdateAsync(T entity, CancellationToken cancellationToken = default)
    {
        _dbSet.Update(entity);
        await context.SaveChangesAsync(cancellationToken);
    }

    public async Task DeleteAsync(T entity, CancellationToken cancellationToken = default)
    {
        _dbSet.Remove(entity);
        await context.SaveChangesAsync(cancellationToken);
    }
}
```

### TodoItem Entity Configuration with HasData Seed
```csharp
// Source: https://learn.microsoft.com/en-us/ef/core/modeling/data-seeding
namespace Starter.Data.Configuration;

internal sealed class TodoItemConfiguration : IEntityTypeConfiguration<TodoItem>
{
    public void Configure(EntityTypeBuilder<TodoItem> builder)
    {
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Title).IsRequired().HasMaxLength(200);
        builder.Property(t => t.CreatedAt).IsRequired();

        // Seed data -- requires explicit PK values
        builder.HasData(
            new TodoItem { Id = 1, Title = "Learn EF Core", IsComplete = true, CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc) },
            new TodoItem { Id = 2, Title = "Build an API", IsComplete = false, CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc) },
            new TodoItem { Id = 3, Title = "Deploy to production", IsComplete = false, CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc) }
        );
    }
}
```

### appsettings.json Database Section
```json
{
  "Database": {
    "Provider": "Sqlite",
    "AutoMigrate": true,
    "CommandTimeout": 30,
    "EnableSensitiveDataLogging": false,
    "MaxRetryCount": 3
  },
  "ConnectionStrings": {
    "Sqlite": "Data Source=starter.db",
    "SqlServer": "Server=(localdb)\\mssqllocaldb;Database=StarterDb;Trusted_Connection=True;",
    "PostgreSql": "Host=localhost;Database=starterdb;Username=postgres;Password=postgres"
  }
}
```

### Migration Script Example (add-migration.sh)
```bash
#!/usr/bin/env bash
# Usage: ./scripts/add-migration.sh <Provider> <MigrationName>
# Example: ./scripts/add-migration.sh Sqlite InitialCreate

set -euo pipefail

PROVIDER="${1:?Usage: add-migration.sh <Sqlite|SqlServer|PostgreSql> <MigrationName>}"
MIGRATION_NAME="${2:?Usage: add-migration.sh <Provider> <MigrationName>}"

case "$PROVIDER" in
    Sqlite)     PROJECT="src/Starter.Data.Migrations.Sqlite" ;;
    SqlServer)  PROJECT="src/Starter.Data.Migrations.SqlServer" ;;
    PostgreSql) PROJECT="src/Starter.Data.Migrations.PostgreSql" ;;
    *)          echo "Error: Unknown provider '$PROVIDER'. Use: Sqlite, SqlServer, PostgreSql"; exit 1 ;;
esac

dotnet ef migrations add "$MIGRATION_NAME" \
    --startup-project src/Starter.WebApi \
    --project "$PROJECT" \
    -- --provider "$PROVIDER"
```

### Migration Class Library .csproj (example: SQLite)
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="10.0.5" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\Starter.Data\Starter.Data.csproj" />
  </ItemGroup>

</Project>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Output directory per provider (`--output-dir`) | Separate migration assembly projects (`MigrationsAssembly()`) | EF Core 5+ (refined in 8+) | Clean isolation of per-provider migration history and snapshots |
| HasData only for seeding | UseSeeding/UseAsyncSeeding (EF9+) for complex/runtime seeding; HasData for static model-managed data | EF Core 9 (Nov 2024) | HasData still correct for small deterministic seed data; UseSeeding for dynamic data |
| `DateTimeOffset` with local timezone assumption in SQLite | UTC-first handling in Microsoft.Data.Sqlite 10 | EF Core 10 (Nov 2025) | DateTime.UtcNow is now the correct default; local time assumptions will cause bugs |
| OPENJSON for parameterized collections (EF8-9) | Multiple scalar parameters by default (EF10) | EF Core 10 (Nov 2025) | Performance improvement for most queries; can revert per-query if needed |
| Global `dotnet-ef` could auto-detect framework | Must specify `--framework` for multi-targeted projects (EF10) | EF Core 10 (Nov 2025) | Not applicable to this project (single target) but worth knowing |

**Deprecated/outdated:**
- `EnsureCreated()` should NOT be used alongside Migrations -- they are mutually exclusive strategies
- `OnConfiguring` for production provider configuration -- use DI `AddDbContext` instead
- String-based assembly names for `MigrationsAssembly()` -- use `typeof(Marker).Assembly.GetName().Name` for refactoring safety

## Open Questions

1. **ApplyConfigurationsFromAssembly cross-assembly discovery for Phase 4**
   - What we know: Phase 4 Identity entities will be added to the same AppDbContext. The CONTEXT.md says configurations "get discovered automatically" via assembly scanning.
   - What's unclear: If Phase 4 configurations live in a separate assembly (e.g., Starter.Auth), a single `ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly)` call won't find them.
   - Recommendation: For now, implement with single assembly scanning. Phase 4 planning will decide whether to: (a) add Identity entity configs directly in Starter.Data, or (b) add a second `ApplyConfigurationsFromAssembly()` call in `OnModelCreating`. Both approaches are straightforward.

2. **EF Core Design package placement**
   - What we know: `Microsoft.EntityFrameworkCore.Design` is needed by `dotnet ef` tooling. It can go on the startup project or the context project.
   - What's unclear: Whether it should be on Starter.Data (closer to the context) or Starter.WebApi (the startup project that `dotnet ef` runs against).
   - Recommendation: Place on Starter.Data with `<PrivateAssets>all</PrivateAssets>` and `<IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>`. This keeps design-time tooling near the DbContext while preventing transitive leaks. The startup project also needs a reference via the project reference chain.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None yet -- Testing is Phase 6 |
| Config file | none -- see Wave 0 |
| Quick run command | `dotnet build Starter.WebApi.slnx` (compile check) |
| Full suite command | N/A until Phase 6 |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATA-01 | SQLite configures with zero setup | smoke | `dotnet run --project src/Starter.WebApi` + verify DB file created | -- Wave 0 |
| DATA-02 | SQL Server provider swappable | manual-only | Requires SQL Server instance to validate | -- Phase 6 |
| DATA-03 | PostgreSQL provider swappable | manual-only | Requires PostgreSQL instance to validate | -- Phase 6 |
| DATA-04 | Separate migration assemblies per provider | unit | `dotnet ef migrations list --startup-project src/Starter.WebApi --project src/Starter.Data.Migrations.Sqlite -- --provider Sqlite` | -- Wave 0 |
| DATA-05 | Migration helper scripts provided | smoke | `./scripts/add-migration.sh Sqlite TestMigration` (then revert) | -- Wave 0 |
| DATA-06 | Repository/service layer wraps DbContext | smoke | `curl` to TodoController CRUD endpoints after app start | -- Wave 0 |

### Sampling Rate

- **Per task commit:** `dotnet build Starter.WebApi.slnx` -- ensures compilation
- **Per wave merge:** Run application and verify SQLite DB creation + CRUD via TodoController
- **Phase gate:** All projects compile, SQLite auto-creates, TodoItem CRUD works end-to-end

### Wave 0 Gaps

- [ ] No test project exists yet -- Testing is Phase 6
- [ ] Verification is currently manual: run app, check SQLite file, exercise CRUD endpoints
- [ ] Framework install deferred to Phase 6: `dotnet new xunit -n Starter.Tests.Integration`

*(Formal automated testing infrastructure is Phase 6. Phase 3 validation is compilation + manual smoke testing.)*

## Sources

### Primary (HIGH confidence)
- [Migrations with Multiple Providers - EF Core (Microsoft Learn)](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/providers) -- Official multi-provider migration pattern with `MigrationsAssembly()` and `--provider` arg forwarding
- [Using a Separate Migrations Project - EF Core (Microsoft Learn)](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/projects) -- Official separate migration project setup
- [Breaking changes in EF Core 10 (Microsoft Learn)](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-10.0/breaking-changes) -- Full list of EF10 breaking changes including SQLite timezone handling
- [Data Seeding - EF Core (Microsoft Learn)](https://learn.microsoft.com/en-us/ef/core/modeling/data-seeding) -- HasData vs UseSeeding/UseAsyncSeeding comparison
- [What's New in EF Core 10 (Microsoft Learn)](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-10.0/whatsnew) -- EF10 new features
- NuGet registry (verified 2026-03-18): EF Core 10.0.5, SQLite 10.0.5, SqlServer 10.0.5, Npgsql 10.0.1, dotnet-ef 10.0.5

### Secondary (MEDIUM confidence)
- [Anton Dev Tips: How To Create Migrations For Multiple Databases](https://antondevtips.com/blog/how-to-create-migrations-for-multiple-databases-in-ef-core) -- Practical marker interface + migration assembly pattern
- [Damir's Corner: Support Multiple DB Providers in EF Core](https://www.damirscorner.com/blog/posts/20240405-SupportMultipleDbProvidersInEfCore.html) -- Alternative approach with DbContext inheritance
- [Npgsql Documentation: NpgsqlRetryingExecutionStrategy](https://www.npgsql.org/efcore/api/Npgsql.EntityFrameworkCore.PostgreSQL.NpgsqlRetryingExecutionStrategy.html) -- PostgreSQL retry strategy
- [Connection Resiliency - EF Core (Microsoft Learn)](https://learn.microsoft.com/en-us/ef/core/miscellaneous/connection-resiliency) -- EnableRetryOnFailure documentation

### Tertiary (LOW confidence)
- None -- all findings verified with primary or secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All package versions verified against NuGet registry on 2026-03-18
- Architecture: HIGH -- Multi-provider separate migration assembly pattern is from official Microsoft docs, confirmed stable since EF Core 5+
- Pitfalls: HIGH -- Breaking changes documented in official EF10 release notes; tool version mismatch confirmed by checking local `dotnet-ef` version (8.0.6)
- Code examples: MEDIUM-HIGH -- Patterns synthesized from official docs and verified community implementations; exact API shapes confirmed against Microsoft docs

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (stable LTS release, unlikely to change)
