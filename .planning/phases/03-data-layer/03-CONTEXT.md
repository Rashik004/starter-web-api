# Phase 3: Data Layer - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Add an EF Core data layer as a removable module (`Starter.Data`) with SQLite as the zero-config development default, multi-provider support (SQL Server, PostgreSQL) switchable via appsettings.json, separate migration assemblies per provider, and a sample TodoItem entity with repository/service pattern demonstrating end-to-end CRUD.

</domain>

<decisions>
## Implementation Decisions

### Provider switching mechanism
- String-based provider name in `Database:Provider` key with values `Sqlite`, `SqlServer`, `PostgreSql`
- All three connection strings pre-populated in appsettings.json — SQLite has a working default, SQL Server and PostgreSQL have placeholder values
- Invalid provider name causes immediate startup failure via ValidateOnStart (no silent fallback)
- Config section includes common EF options: CommandTimeout, EnableSensitiveDataLogging, MaxRetryCount (appsettings-driven)

### Sample entity & data access pattern
- TodoItem entity (Id, Title, IsComplete, CreatedAt) as the sample — simple, universally understood, easy to delete
- Generic `IRepository<T>` interface in Starter.Shared, concrete `EfRepository<T>` in Starter.Data (internal)
- Full service layer: Controller → ITodoService → IRepository<TodoItem>
- Entity (TodoItem) lives in Starter.Data, not Shared — only interfaces (IRepository<T>, ITodoService) live in Shared
- Controllers work with DTOs/interface return types, not EF entity types directly

### Migration workflow
- Separate migration projects per provider: `Starter.Data.Migrations.Sqlite`, `Starter.Data.Migrations.SqlServer`, `Starter.Data.Migrations.PostgreSql`
- Shell scripts (bash + PowerShell) wrap `dotnet ef` with correct `--project` and `--startup-project` flags per provider
- Scripts live in `scripts/` directory: `add-migration.sh/.ps1`, `update-database.sh/.ps1`
- Auto-migration on startup controlled by `Database:AutoMigrate` config flag — works in any environment (user's responsibility to disable in production)
- Initial seed migration includes sample TodoItems via `HasData()` for immediate verification

### DbContext ownership & module boundary
- Single `AppDbContext` in Starter.Data owns all entity configurations
- Phase 4 Identity will add its entities to the same context — no separate IdentityDbContext
- Extensibility via `IEntityTypeConfiguration` with assembly scanning (`ApplyConfigurationsFromAssembly()`) — Phase 4 Auth module provides its own configurations that get discovered automatically
- Starter.Data references Starter.Shared for IRepository<T> and shared exception types (NotFoundException, etc.)
- No module-to-module references — Starter.Data does not reference Starter.Auth (or vice versa for data access)

### Claude's Discretion
- EF Core configuration details (retry policies, connection resiliency specifics)
- Exact DTO shape for TodoItem API responses
- TodoService implementation details (validation, business rules)
- Seed data content (specific sample TodoItems)
- Script implementation details (argument parsing, error messages)
- Whether to include EF Core interceptors or query filters

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project foundation
- `.planning/phases/01-solution-scaffold-and-foundation/01-CONTEXT.md` — Extension method naming (`AddApp*`/`UseApp*`), module naming (`Starter.{Module}`), Program.cs grouped-by-concern layout, internal visibility pattern, IOptions with ValidateOnStart
- `.planning/phases/02-observability/02-CONTEXT.md` — Logging module as reference for module structure, appsettings section pattern with `Enabled` flags
- `.planning/REQUIREMENTS.md` — DATA-01..DATA-06 define the scope for this phase

### Existing code
- `src/Starter.WebApi/Program.cs` — Composition root with `// --- Data ---` placeholder at line 25
- `src/Starter.Logging/LoggingExtensions.cs` — Reference pattern for `AddApp*`/`UseApp*` extension methods and `WebApplicationBuilder` extension style
- `src/Starter.Shared/Exceptions/` — Shared exception types (NotFoundException, etc.) that the data layer should use
- `src/Starter.WebApi/appsettings.json` — Current configuration structure to extend with Database section

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Starter.Shared/Exceptions/NotFoundException.cs` — Data layer should throw this when entity not found by ID
- `LoggingExtensions.cs` — Reference pattern for the `AddAppData()` extension method structure
- `ExceptionHandlingExtensions.cs` — Reference pattern for `AddApp*`/`UseApp*` naming and registration

### Established Patterns
- IOptions<T> with ValidateDataAnnotations and ValidateOnStart — Database config section must follow this
- `internal` visibility by default; only extension methods and contracts are `public`
- Module config sections in appsettings.json with JSON comments explaining configuration
- Extension methods on `WebApplicationBuilder` (not just `IServiceCollection`) when configuration access is needed

### Integration Points
- `Program.cs` line 25: `// --- Data ---` placeholder is where `AddAppData()` goes (services registration)
- `Program.cs` line 39: `// (Phase 4: app.UseAuthentication(), app.UseAuthorization())` — no middleware needed for data layer
- `appsettings.json` needs `Database` configuration section added
- `Starter.Shared` needs `IRepository<T>` and `ITodoService` interfaces added
- Solution file needs 4 new projects: Starter.Data + 3 migration assemblies

</code_context>

<specifics>
## Specific Ideas

- The provider switching should feel like a one-line config change: flip `Provider` from `Sqlite` to `SqlServer`, and the matching connection string is already there waiting
- Migration scripts should be copy-paste friendly — run `./scripts/add-migration.sh Sqlite InitialCreate` and it just works with the right assembly targeting
- AppDbContext should be ready for Phase 4 Identity integration without needing structural changes (assembly scanning already in place)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-data-layer*
*Context gathered: 2026-03-18*
