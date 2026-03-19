---
phase: 03-data-layer
plan: 03
subsystem: database
tags: [ef-core, sqlite, migrations, dotnet-ef, crud, seed-data, helper-scripts]

# Dependency graph
requires:
  - phase: 03-data-layer
    plan: 01
    provides: "AppDbContext, migration assembly projects with Marker classes, DatabaseOptions, DataExtensions"
  - phase: 03-data-layer
    plan: 02
    provides: "TodoController with 5 CRUD endpoints, EfRepository/TodoService implementations, appsettings.json Database config"
provides:
  - "Migration helper scripts (add-migration and update-database) for bash and PowerShell with multi-provider support"
  - "SQLite initial migration with TodoItems table and 3 seed data rows"
  - "Verified end-to-end CRUD flow: app start -> auto-migrate -> SQLite DB created -> seed data -> REST API"
  - "dotnet-ef 10.0.5 global tool installed"
affects: [04-security-and-api, 05-hardening, 06-testing]

# Tech tracking
tech-stack:
  added: [dotnet-ef 10.0.5 (global tool)]
  patterns: [environment variable provider override for dotnet-ef, cross-platform migration scripts]

key-files:
  created:
    - scripts/add-migration.sh
    - scripts/add-migration.ps1
    - scripts/update-database.sh
    - scripts/update-database.ps1
    - src/Starter.Data.Migrations.Sqlite/Migrations/20260318144423_InitialCreate.cs
    - src/Starter.Data.Migrations.Sqlite/Migrations/20260318144423_InitialCreate.Designer.cs
    - src/Starter.Data.Migrations.Sqlite/Migrations/AppDbContextModelSnapshot.cs
  modified:
    - .gitignore
    - src/Starter.Data/Starter.Data.csproj
    - src/Starter.WebApi/Starter.WebApi.csproj

key-decisions:
  - "Environment variable (Database__Provider) used in migration scripts instead of -- --provider CLI arg for reliable configuration override"
  - "starter.db and all .db/.db-shm/.db-wal files gitignored to prevent runtime database commits"

patterns-established:
  - "Migration script pattern: scripts/add-migration.sh <Provider> <Name> with Database__Provider env var override and --project/--startup-project flags"
  - "Cross-platform script pattern: every bash script has a matching PowerShell script with identical behavior"

requirements-completed: [DATA-04, DATA-05]

# Metrics
duration: 4min
completed: 2026-03-18
---

# Phase 3 Plan 03: Migration Scripts and SQLite Initial Migration Summary

**Migration helper scripts (bash + PowerShell) for all 3 providers, SQLite initial migration with TodoItems table and seed data, and verified end-to-end CRUD from TodoController through auto-migrated SQLite database**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-18T14:43:00Z
- **Completed:** 2026-03-18T14:55:05Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- Created 4 migration helper scripts (add-migration and update-database in both bash and PowerShell) supporting all 3 database providers via ValidateSet/case statement
- Upgraded dotnet-ef global tool to version 10.0.5 for EF Core 10 compatibility
- Generated SQLite initial migration capturing TodoItems table schema and 3 HasData seed rows (InsertData calls in Up method)
- Added .gitignore entries for SQLite runtime database files (*.db, *.db-shm, *.db-wal)
- Verified complete end-to-end flow: application starts with default SQLite config, auto-creates starter.db, seeds 3 todo items, and all 5 CRUD operations return correct HTTP status codes (200, 201, 204, 404)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create migration helper scripts and upgrade dotnet-ef tool** - `c1421a8` (feat)
2. **Task 2: Generate initial SQLite migration and add starter.db to .gitignore** - `9f0771e` (feat)
3. **Task 3: Verify end-to-end CRUD via TodoController** - checkpoint:human-verify (approved, no commit needed)

## Files Created/Modified
- `scripts/add-migration.sh` - Bash wrapper for dotnet ef migrations add with multi-provider targeting
- `scripts/add-migration.ps1` - PowerShell wrapper for dotnet ef migrations add with ValidateSet provider parameter
- `scripts/update-database.sh` - Bash wrapper for dotnet ef database update with optional migration name
- `scripts/update-database.ps1` - PowerShell wrapper for dotnet ef database update with optional migration name
- `src/Starter.Data.Migrations.Sqlite/Migrations/20260318144423_InitialCreate.cs` - Up/Down migration creating TodoItems table with 3 seed rows
- `src/Starter.Data.Migrations.Sqlite/Migrations/20260318144423_InitialCreate.Designer.cs` - Migration metadata
- `src/Starter.Data.Migrations.Sqlite/Migrations/AppDbContextModelSnapshot.cs` - Current model snapshot for SQLite provider
- `.gitignore` - Added *.db, *.db-shm, *.db-wal entries
- `src/Starter.Data/Starter.Data.csproj` - Updated during migration generation
- `src/Starter.WebApi/Starter.WebApi.csproj` - Updated during migration generation

## Decisions Made

1. **Environment variable override for provider in scripts** - Used `Database__Provider=$PROVIDER` environment variable prefix instead of `-- --provider $PROVIDER` CLI argument forwarding. The env var maps directly to the `Database:Provider` configuration key without requiring custom argument parsing in the application, making it more reliable across different host builder configurations.

2. **SQLite database files gitignored** - Added `*.db`, `*.db-shm`, `*.db-wal` patterns to .gitignore. The starter.db file is generated at runtime by auto-migration and should not be committed since it contains runtime state.

## Deviations from Plan

None - plan executed exactly as written. Migration scripts created, initial migration generated, and E2E verification passed on first attempt.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. The application auto-creates and auto-migrates the SQLite database on first startup.

## Next Phase Readiness
- Phase 3 (Data Layer) is fully complete: EF Core module, multi-provider support, migration assemblies, CRUD vertical slice, and migration tooling all verified working
- Phase 4 (Security and API Surface) can add Identity entities to AppDbContext and generate new migrations using the helper scripts
- AppDbContext is intentionally non-sealed to support Phase 4 Identity extensibility
- Migration scripts support all 3 providers -- SqlServer and PostgreSQL migrations can be generated when those connection strings are configured

## Self-Check: PASSED

All 7 created files verified on disk. Both task commits (c1421a8, 9f0771e) verified in git log. Task 3 was a human-verify checkpoint approved by user -- no commit required.

---
*Phase: 03-data-layer*
*Completed: 2026-03-18*
