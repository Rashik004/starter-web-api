#!/usr/bin/env bash
# Usage: ./scripts/select-db-provider.sh [--provider Sqlite|SqlServer|PostgreSql] [--prefix Name]
#                                        [--dry-run] [--no-backup-branch] [--force] [--skip-build]
# Example: ./scripts/select-db-provider.sh --provider Sqlite
# Example: ./scripts/select-db-provider.sh --prefix Acme --provider PostgreSql
# Example: ./scripts/select-db-provider.sh --dry-run
#
# Trims repo to a single EF Core database provider.
# Removes the two unused migration projects, trims .slnx + .csproj references,
# strips unused EF packages, rewrites DataExtensions.cs + DatabaseOptions.cs,
# and cleans appsettings. Stages changes (no commit).
#
# Detects the project prefix from '*.WebApi.slnx' (override with --prefix).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse arguments ─────────────────────────────────────────────────────────

PROVIDER=""
PREFIX=""
DRY_RUN=false
NO_BACKUP_BRANCH=false
FORCE=false
SKIP_BUILD=false

usage() {
    sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider)         PROVIDER="$2"; shift 2 ;;
        --prefix)           PREFIX="$2"; shift 2 ;;
        --dry-run)          DRY_RUN=true; shift ;;
        --no-backup-branch) NO_BACKUP_BRANCH=true; shift ;;
        --force)            FORCE=true; shift ;;
        --skip-build)       SKIP_BUILD=true; shift ;;
        -h|--help)          usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────────

tag() { printf '[%s] %s\n' "$1" "$2"; }

confirm() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

# Delete every line containing the given fixed string. Portable in-place edit.
remove_line_containing() {
    local needle="$1" file="$2" tmp
    tmp="$(mktemp)"
    grep -vF "$needle" "$file" > "$tmp" || true
    mv "$tmp" "$file"
}

resolve_prefix() {
    if [[ -n "$PREFIX" ]]; then
        if [[ ! "$PREFIX" =~ ^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$ ]]; then
            echo "Invalid prefix '$PREFIX'. Must be a C# identifier or dotted namespace (e.g., 'Acme' or 'Acme.Server')." >&2
            exit 1
        fi
        if [[ ! -f "$ROOT_DIR/src/$PREFIX.WebApi.slnx" ]]; then
            echo "No 'src/$PREFIX.WebApi.slnx' in $ROOT_DIR. Check --prefix value." >&2
            exit 1
        fi
        return
    fi

    local matches=() f
    for f in "$ROOT_DIR"/src/*.WebApi.slnx; do
        [[ -f "$f" ]] && matches+=("$f")
    done

    if [[ ${#matches[@]} -eq 1 ]]; then
        local base
        base="$(basename "${matches[0]}" .slnx)"
        PREFIX="${base%.WebApi}"
        tag DETECT "Prefix '$PREFIX' (from src/$(basename "${matches[0]}"))"
        return
    fi

    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "No *.WebApi.slnx found in $ROOT_DIR/src. Pass --prefix explicitly." >&2
        exit 1
    fi

    echo "Multiple *.WebApi.slnx files found in src/:" >&2
    for f in "${matches[@]}"; do echo "  $(basename "$f")" >&2; done
    echo "Pass --prefix explicitly." >&2
    exit 1
}

# ── Templates ──────────────────────────────────────────────────────────────

emit_data_extensions() {
    local keep="$1" pfx="$2"
    local migrations_asm="$pfx.Data.Migrations.$keep"
    local provider_block

    case "$keep" in
        Sqlite)
            provider_block=$(cat <<'EOF'
            options.UseSqlite(
                builder.Configuration.GetConnectionString("Sqlite"),
                x =>
                {
                    x.MigrationsAssembly(MigrationsAssembly);
                    if (dbOptions.CommandTimeout > 0)
                        x.CommandTimeout(dbOptions.CommandTimeout);
                });
EOF
            )
            ;;
        SqlServer)
            provider_block=$(cat <<'EOF'
            options.UseSqlServer(
                builder.Configuration.GetConnectionString("SqlServer"),
                x =>
                {
                    x.MigrationsAssembly(MigrationsAssembly);
                    x.EnableRetryOnFailure(
                        maxRetryCount: dbOptions.MaxRetryCount,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                    if (dbOptions.CommandTimeout > 0)
                        x.CommandTimeout(dbOptions.CommandTimeout);
                });
EOF
            )
            ;;
        PostgreSql)
            provider_block=$(cat <<'EOF'
            options.UseNpgsql(
                builder.Configuration.GetConnectionString("PostgreSql"),
                x =>
                {
                    x.MigrationsAssembly(MigrationsAssembly);
                    x.EnableRetryOnFailure(
                        maxRetryCount: dbOptions.MaxRetryCount,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorCodesToAdd: null);
                    if (dbOptions.CommandTimeout > 0)
                        x.CommandTimeout(dbOptions.CommandTimeout);
                });
EOF
            )
            ;;
    esac

    cat <<EOF
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using $pfx.Data.Options;
using $pfx.Data.Repositories;
using $pfx.Data.Services;
using $pfx.Shared.Contracts;

namespace $pfx.Data;

public static class DataExtensions
{
    private const string MigrationsAssembly = "$migrations_asm";

    /// <summary>
    /// Registers EF Core data services using the $keep provider.
    /// </summary>
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
$provider_block

            if (dbOptions.EnableSensitiveDataLogging)
                options.EnableSensitiveDataLogging();
        });

        builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
        builder.Services.AddScoped<ITodoService, TodoService>();

        return builder;
    }

    /// <summary>
    /// Applies pending EF Core migrations on startup when <c>Database:AutoMigrate</c> is true.
    /// </summary>
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
}
EOF
}

emit_database_options() {
    local keep="$1" pfx="$2" retry_line=""
    if [[ "$keep" != "Sqlite" ]]; then
        retry_line=$'    public int MaxRetryCount { get; set; } = 3;\n'
    fi

    cat <<EOF
using System.ComponentModel.DataAnnotations;

namespace $pfx.Data.Options;

internal sealed class DatabaseOptions
{
    public const string SectionName = "Database";

    public bool AutoMigrate { get; set; } = true;
    public int CommandTimeout { get; set; }
    public bool EnableSensitiveDataLogging { get; set; }
$retry_line}
EOF
}

# ── Preflight ──────────────────────────────────────────────────────────────

cd "$ROOT_DIR"

resolve_prefix
PREFIX_LOWER="$(echo "$PREFIX" | tr '[:upper:]' '[:lower:]')"

# Idempotency guard: if only one migration project remains, the repo is
# already trimmed. Re-running would silently rewrite DataExtensions.cs from
# template, blowing away any manual edits. Require --force to proceed.
MIGRATIONS_DIR="$ROOT_DIR/src/Migrations"
if [[ -d "$MIGRATIONS_DIR" ]]; then
    existing=()
    shopt -s nullglob
    for d in "$MIGRATIONS_DIR/$PREFIX.Data.Migrations."*/; do
        [[ -d "$d" ]] && existing+=("$d")
    done
    shopt -u nullglob
    if [[ ${#existing[@]} -le 1 ]] && ! $FORCE && ! $DRY_RUN; then
        if [[ ${#existing[@]} -eq 1 ]]; then
            kept="$(basename "${existing[0]%/}")"
            kept="${kept#"$PREFIX.Data.Migrations."}"
        else
            kept="(none)"
        fi
        echo "Repo appears already trimmed to $kept (${#existing[@]} migration project(s) found)." >&2
        echo "Pass --force to re-run anyway, or --dry-run to see what would change." >&2
        exit 1
    fi
fi

if ! $FORCE && ! $DRY_RUN; then
    dirty="$(git status --porcelain 2>/dev/null || true)"
    if [[ -n "$dirty" ]]; then
        echo "Git working tree is dirty:"
        echo "$dirty"
        if ! confirm "Proceed anyway?"; then
            echo "Aborted: commit or stash your changes first, or pass --force." >&2
            exit 1
        fi
    fi
fi

if [[ -z "$PROVIDER" ]]; then
    echo ""
    echo "Select the database provider to keep:"
    echo "  1) Sqlite     (default, zero-config, file-based)"
    echo "  2) SqlServer"
    echo "  3) PostgreSql"
    read -r -p "Choice [1-3] (default: 1) " choice
    choice="${choice:-1}"
    case "$choice" in
        1) PROVIDER=Sqlite ;;
        2) PROVIDER=SqlServer ;;
        3) PROVIDER=PostgreSql ;;
        *) echo "Invalid choice: $choice" >&2; exit 1 ;;
    esac
fi

case "$PROVIDER" in
    Sqlite|SqlServer|PostgreSql) ;;
    *) echo "Invalid provider '$PROVIDER'. Use: Sqlite, SqlServer, PostgreSql" >&2; exit 1 ;;
esac

DROP=()
for p in Sqlite SqlServer PostgreSql; do
    [[ "$p" != "$PROVIDER" ]] && DROP+=("$p")
done

echo ""
echo "Plan:"
echo "  Prefix: $PREFIX"
echo "  Keep:   $PROVIDER"
echo "  Drop:   ${DROP[*]}"
$DRY_RUN && echo "  Mode:   DRY RUN (no changes)"
echo ""

if ! $DRY_RUN && ! $FORCE; then
    confirm "Continue?" || { echo "Aborted by user." >&2; exit 1; }
fi

# ── 1. Backup branch ───────────────────────────────────────────────────────

if ! $DRY_RUN && ! $NO_BACKUP_BRANCH; then
    ts="$(date +%Y%m%d-%H%M%S)"
    branch="pre-db-trim-$ts"
    tag GIT "Creating backup branch '$branch'"
    git checkout -b "$branch" >/dev/null
    git checkout - >/dev/null
    tag GIT "Backup branch created. Return with: git checkout $branch"
fi

# ── 2. Delete migration projects ──────────────────────────────────────────

for d in "${DROP[@]}"; do
    path="$ROOT_DIR/src/Migrations/$PREFIX.Data.Migrations.$d"
    if [[ -d "$path" ]]; then
        tag DELETE "$path"
        $DRY_RUN || rm -rf "$path"
    else
        tag SKIP "$path (missing)"
    fi
done

# ── 3. Edit .slnx ─────────────────────────────────────────────────────────

SLNX_PATH="$ROOT_DIR/src/$PREFIX.WebApi.slnx"
tag EDIT "$SLNX_PATH"
if ! $DRY_RUN; then
    for d in "${DROP[@]}"; do
        needle="Path=\"Migrations/$PREFIX.Data.Migrations.$d/$PREFIX.Data.Migrations.$d.csproj\""
        remove_line_containing "$needle" "$SLNX_PATH"
    done
fi

# ── 4. Edit host .csproj ──────────────────────────────────────────────────

HOST_CSPROJ="$ROOT_DIR/src/Host/$PREFIX.WebApi/$PREFIX.WebApi.csproj"
tag EDIT "$HOST_CSPROJ"
if ! $DRY_RUN; then
    for d in "${DROP[@]}"; do
        needle="Include=\"..\\..\\Migrations\\$PREFIX.Data.Migrations.$d\\$PREFIX.Data.Migrations.$d.csproj\""
        remove_line_containing "$needle" "$HOST_CSPROJ"
    done
fi

# ── 5. Edit data .csproj: drop InternalsVisibleTo + unused EF packages ─────

DATA_CSPROJ="$ROOT_DIR/src/Modules/$PREFIX.Data/$PREFIX.Data.csproj"
tag EDIT "$DATA_CSPROJ"
declare -A PROVIDER_PACKAGE=(
    [Sqlite]=Microsoft.EntityFrameworkCore.Sqlite
    [SqlServer]=Microsoft.EntityFrameworkCore.SqlServer
    [PostgreSql]=Npgsql.EntityFrameworkCore.PostgreSQL
)
if ! $DRY_RUN; then
    for d in "${DROP[@]}"; do
        ivt="Include=\"$PREFIX.Data.Migrations.$d\""
        remove_line_containing "$ivt" "$DATA_CSPROJ"

        pkg="${PROVIDER_PACKAGE[$d]}"
        pkg_needle="PackageReference Include=\"$pkg\""
        remove_line_containing "$pkg_needle" "$DATA_CSPROJ"
    done
fi

# ── 6. Rewrite DataExtensions.cs ──────────────────────────────────────────

DATA_EXT_PATH="$ROOT_DIR/src/Modules/$PREFIX.Data/DataExtensions.cs"
tag EDIT "$DATA_EXT_PATH"
if ! $DRY_RUN; then
    emit_data_extensions "$PROVIDER" "$PREFIX" > "$DATA_EXT_PATH"
fi

# ── 7. Rewrite DatabaseOptions.cs ─────────────────────────────────────────

DB_OPTS_PATH="$ROOT_DIR/src/Modules/$PREFIX.Data/Options/DatabaseOptions.cs"
tag EDIT "$DB_OPTS_PATH"
if ! $DRY_RUN; then
    emit_database_options "$PROVIDER" "$PREFIX" > "$DB_OPTS_PATH"
fi

# ── 8. Edit appsettings files ─────────────────────────────────────────────

APPSETTINGS_FILES=(
    "src/Host/$PREFIX.WebApi/appsettings.json"
    "src/Host/$PREFIX.WebApi/appsettings.Development.json"
)
for rel in "${APPSETTINGS_FILES[@]}"; do
    path="$ROOT_DIR/$rel"
    [[ -f "$path" ]] || continue
    tag EDIT "$path"
    $DRY_RUN && continue

    # Remove "Provider": line (Database section)
    remove_line_containing '"Provider":' "$path"

    # Remove "MaxRetryCount": when keeping Sqlite (Sqlite ignores it)
    if [[ "$PROVIDER" == "Sqlite" ]]; then
        remove_line_containing '"MaxRetryCount":' "$path"
    fi

    # Remove dropped providers from ConnectionStrings
    for d in "${DROP[@]}"; do
        remove_line_containing "\"$d\":" "$path"
    done
done

# ── 9. Delete SQLite DB file if switching away from Sqlite ────────────────

if [[ "$PROVIDER" != "Sqlite" ]]; then
    host_dir="$ROOT_DIR/src/Host/$PREFIX.WebApi"
    if [[ -d "$host_dir" ]]; then
        shopt -s nullglob
        for f in "$host_dir/$PREFIX_LOWER".db*; do
            tag DELETE "$f"
            $DRY_RUN || rm -f "$f"
        done
        shopt -u nullglob
    fi
fi

# ── 9b. Trim Docker compose files ────────────────────────────────────────

COMPOSE_DIR="$ROOT_DIR/docker"

declare -A PROVIDER_TO_FILE=(
    [Sqlite]="compose.sqlite.yaml"
    [PostgreSql]="compose.postgres.yaml"
    [SqlServer]="compose.sqlserver.yaml"
)

KEEP_FILENAME="${PROVIDER_TO_FILE[$PROVIDER]}"
KEEP_PATH="$COMPOSE_DIR/$KEEP_FILENAME"
FINAL_PATH="$COMPOSE_DIR/compose.yaml"

git_tracked() { git -C "$ROOT_DIR" ls-files --error-unmatch "$1" >/dev/null 2>&1; }

if [[ ! -d "$COMPOSE_DIR" ]]; then
    tag SKIP "docker/ directory absent — skipping compose trim"
elif [[ ! -f "$KEEP_PATH" ]]; then
    # Idempotency: if compose.yaml exists and no shards remain, already trimmed
    shopt -s nullglob
    _shards=("$COMPOSE_DIR"/compose.*.yaml)
    shopt -u nullglob
    if [[ -f "$FINAL_PATH" && ${#_shards[@]} -eq 0 ]]; then
        tag SKIP "compose files already trimmed — skipping"
    else
        tag WARN "kept compose file '$KEEP_FILENAME' missing — leaving compose dir untouched"
    fi
else
    # Delete unused compose shards
    shopt -s nullglob
    for shard in "$COMPOSE_DIR"/compose.*.yaml; do
        if [[ "$shard" != "$KEEP_PATH" ]]; then
            tag DELETE "$shard"
            if ! $DRY_RUN; then
                if git_tracked "$shard"; then
                    git -C "$ROOT_DIR" rm "$shard"
                else
                    rm -f "$shard"
                fi
            fi
        fi
    done
    shopt -u nullglob
    # Rename kept shard → compose.yaml (skip if already at final path)
    if [[ "$KEEP_PATH" != "$FINAL_PATH" ]]; then
        tag EDIT "$KEEP_PATH -> $FINAL_PATH"
        if ! $DRY_RUN; then
            if git_tracked "$KEEP_PATH"; then
                git -C "$ROOT_DIR" mv "$KEEP_PATH" "$FINAL_PATH"
            else
                mv -f "$KEEP_PATH" "$FINAL_PATH"
            fi
        fi
    fi
fi

# ── 10. Warn about architecture tests ─────────────────────────────────────

ARCH_SCRIPTS=(
    "src/tests/$PREFIX.WebApi.Tests.Architecture/Scripts/test-module-removal.ps1"
    "src/tests/$PREFIX.WebApi.Tests.Architecture/Scripts/test-module-removal.sh"
)
for rel in "${ARCH_SCRIPTS[@]}"; do
    if [[ -f "$ROOT_DIR/$rel" ]]; then
        tag WARN "Manual edit needed: $rel references dropped migration project(s)"
    fi
done

# ── 11. Build verify ──────────────────────────────────────────────────────

if ! $DRY_RUN && ! $SKIP_BUILD; then
    echo ""
    tag BUILD "dotnet restore + build"
    if ! dotnet restore "$SLNX_PATH" >/dev/null; then
        echo "dotnet restore failed." >&2
        exit 1
    fi
    if ! dotnet build "$SLNX_PATH" --nologo -v quiet; then
        echo ""
        echo "Build failed. Rollback with:" >&2
        echo "  git reset --hard HEAD && git clean -fd" >&2
        exit 1
    fi
fi

# ── 12. Stage changes ─────────────────────────────────────────────────────

if ! $DRY_RUN; then
    tag GIT "Staging changes (no commit)"
    git add -A
fi

echo ""
echo "Done. Prefix: $PREFIX. Kept: $PROVIDER. Dropped: ${DROP[*]}."
echo "Next:"
echo "  - Review staged diff: git diff --cached"
echo "  - Commit when ready:  git commit -m 'chore: trim DB providers to $PROVIDER'"
echo "  - Run app:            dotnet run --project src/Host/$PREFIX.WebApi"
