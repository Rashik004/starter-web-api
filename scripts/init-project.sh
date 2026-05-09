#!/usr/bin/env bash
# Usage: ./scripts/init-project.sh [--prefix NewPrefix] [--old-prefix Starter]
#                                  [--provider Sqlite|SqlServer|PostgreSql]
#                                  [--force] [--skip-build] [--no-backup-branch]
#                                  [--include-bootstrap-scripts] [--no-jwt-secret]
# Example: ./scripts/init-project.sh --prefix Acme --provider Sqlite
# Example: ./scripts/init-project.sh --prefix Acme --old-prefix Starter --provider PostgreSql --force
# Example: ./scripts/init-project.sh
#
# Bootstraps a new project from this template:
#   1. Renames the prefix throughout the solution (rename-project.sh).
#   2. Trims to a single DB provider (select-db-provider.sh).
#   3. Generates a JWT signing key and stores it via 'dotnet user-secrets'
#      (skip with --no-jwt-secret).
#
# After rename phase the working tree is necessarily dirty, so --force is
# always forwarded to select-db-provider.sh.
#
# Bootstrap scripts (init-project, rename-project, select-db-provider) are
# left untouched during content replacement by default so the template stays
# reusable. Pass --include-bootstrap-scripts to rewrite them too.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse arguments ─────────────────────────────────────────────────────────

NEW_PREFIX=""
OLD_PREFIX="Starter"
PROVIDER=""
FORCE=false
SKIP_BUILD=false
NO_BACKUP_BRANCH=false
INCLUDE_BOOTSTRAP=false
NO_JWT_SECRET=false

usage() {
    sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)                     NEW_PREFIX="$2"; shift 2 ;;
        --old-prefix)                 OLD_PREFIX="$2"; shift 2 ;;
        --provider)                   PROVIDER="$2"; shift 2 ;;
        --force)                      FORCE=true; shift ;;
        --skip-build)                 SKIP_BUILD=true; shift ;;
        --no-backup-branch)           NO_BACKUP_BRANCH=true; shift ;;
        --include-bootstrap-scripts)  INCLUDE_BOOTSTRAP=true; shift ;;
        --no-jwt-secret)              NO_JWT_SECRET=true; shift ;;
        -h|--help)                    usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────────

confirm() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

# ── Phase 0: Collect & validate inputs ─────────────────────────────────────

if [[ -z "$NEW_PREFIX" ]]; then
    read -r -p "Enter new project prefix (e.g., 'Acme' or 'Acme.Server'): " NEW_PREFIX
fi

if [[ ! "$NEW_PREFIX" =~ ^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$ ]]; then
    echo "Error: Invalid prefix '$NEW_PREFIX'. Must be a C# identifier or dotted namespace (e.g., 'Acme' or 'Acme.Server'). Hyphens are not allowed." >&2
    exit 1
fi

if [[ "$NEW_PREFIX" == "$OLD_PREFIX" ]]; then
    echo "Error: New prefix '$NEW_PREFIX' is the same as old prefix '$OLD_PREFIX'. Nothing to do." >&2
    exit 1
fi

SLNX_FILE="$ROOT_DIR/src/$OLD_PREFIX.WebApi.slnx"
if [[ ! -f "$SLNX_FILE" ]]; then
    echo "Error: Solution file not found: $SLNX_FILE" >&2
    echo "  Are you running from the correct repo, or has the project already been renamed?" >&2
    exit 1
fi

# ── Phase 1: Dirty-tree pushback ───────────────────────────────────────────

if ! $FORCE; then
    dirty="$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null || true)"
    if [[ -n "$dirty" ]]; then
        echo "Git working tree is dirty:"
        echo "$dirty"
        if ! confirm "Proceed anyway?"; then
            echo "Aborted: commit or stash your changes first, or pass --force." >&2
            exit 1
        fi
    fi
fi

# ── Phase 2: Prompt for provider if missing ────────────────────────────────

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

# Bootstrap-script handling: default = skip (template stays reusable).
# Power users pass --include-bootstrap-scripts to opt in.
if $INCLUDE_BOOTSTRAP; then
    SKIP_BOOTSTRAP=false
else
    SKIP_BOOTSTRAP=true
fi

# ── Phase 3: Combined plan summary ─────────────────────────────────────────

echo ""
echo "=== init-project plan ==="
echo "  Rename:        $OLD_PREFIX -> $NEW_PREFIX"
echo "  Provider:      keep $PROVIDER (drop the others)"
echo "  SkipBuild:     $SKIP_BUILD"
echo "  Backup br.:    $(! $NO_BACKUP_BRANCH && echo true || echo false)"
echo "  Skip bootstr.: $SKIP_BOOTSTRAP"
echo "  JWT secret:    $(! $NO_JWT_SECRET && echo "auto-generate" || echo "skipped")"
echo ""
echo "  Step 1/3: scripts/rename-project.sh"
echo "  Step 2/3: scripts/select-db-provider.sh (with --force, since rename leaves tree dirty)"
$NO_JWT_SECRET || echo "  Step 3/3: dotnet user-secrets set Jwt:SecretKey (auto-generated)"
echo ""

if ! $FORCE; then
    confirm "Continue?" || { echo "Aborted by user." >&2; exit 1; }
fi

# ── Phase 4: Rename ────────────────────────────────────────────────────────

echo ""
echo ">>> [1/3] Running rename-project.sh..."
echo ""

rename_args=("$NEW_PREFIX" "$OLD_PREFIX")
$SKIP_BUILD && rename_args+=(--skip-build)
if $INCLUDE_BOOTSTRAP; then
    rename_args+=(--include-bootstrap-scripts)
else
    rename_args+=(--no-include-bootstrap-scripts)
fi

bash "$SCRIPT_DIR/rename-project.sh" "${rename_args[@]}"

# ── Phase 5: DB trim ───────────────────────────────────────────────────────

echo ""
echo ">>> [2/3] Running select-db-provider.sh..."
echo ""

trim_args=(--provider "$PROVIDER" --prefix "$NEW_PREFIX" --force)
$SKIP_BUILD && trim_args+=(--skip-build)
$NO_BACKUP_BRANCH && trim_args+=(--no-backup-branch)

bash "$SCRIPT_DIR/select-db-provider.sh" "${trim_args[@]}"

# ── Phase 6: JWT signing key ───────────────────────────────────────────────

if ! $NO_JWT_SECRET; then
    echo ""
    echo ">>> [3/3] Generating JWT signing key..."
    echo ""

    HOST_CSPROJ="$ROOT_DIR/src/Host/$NEW_PREFIX.WebApi/$NEW_PREFIX.WebApi.csproj"
    if [[ ! -f "$HOST_CSPROJ" ]]; then
        echo "WARNING: host csproj not found at $HOST_CSPROJ — skipping JWT secret." >&2
    else
        # Generate a 48-byte (384-bit) base64-encoded secret.
        if command -v openssl >/dev/null 2>&1; then
            jwt_secret="$(openssl rand -base64 48 | tr -d '\n')"
        else
            jwt_secret="$(head -c 48 /dev/urandom | base64 | tr -d '\n')"
        fi

        # Idempotent: 'init' adds a UserSecretsId only if absent.
        dotnet user-secrets init --project "$HOST_CSPROJ" >/dev/null
        dotnet user-secrets set "Jwt:SecretKey" "$jwt_secret" --project "$HOST_CSPROJ" >/dev/null

        echo "JWT signing key written to user-secrets store for $NEW_PREFIX.WebApi."
        echo "  (Secret value is not echoed. Retrieve with: dotnet user-secrets list --project src/Host/$NEW_PREFIX.WebApi)"
    fi
fi

# ── Phase 7: Done ──────────────────────────────────────────────────────────

echo ""
echo "=== init-project complete ==="
echo "  Renamed:  $OLD_PREFIX -> $NEW_PREFIX"
echo "  Provider: $PROVIDER"
$NO_JWT_SECRET || echo "  JWT key:  set in user-secrets"
echo ""
echo "Next:"
echo "  - Review staged diff: git diff --cached"
echo "  - Commit when ready:  git commit -m 'chore: bootstrap $NEW_PREFIX with $PROVIDER provider'"
echo "  - Run app:            dotnet run --project src/Host/$NEW_PREFIX.WebApi"
echo ""
