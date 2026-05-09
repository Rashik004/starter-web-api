#!/usr/bin/env bash
# Usage: ./scripts/init-project.sh [--prefix NewPrefix] [--old-prefix Starter]
#                                  [--provider Sqlite|SqlServer|PostgreSql]
#                                  [--force] [--skip-build] [--no-backup-branch]
#                                  [--include-bootstrap-scripts] [--no-jwt-secret]
#                                  [--no-env-file]
# Example: ./scripts/init-project.sh --prefix Acme --provider Sqlite
# Example: ./scripts/init-project.sh --prefix Acme --old-prefix Starter --provider PostgreSql --force
# Example: ./scripts/init-project.sh
#
# Bootstraps a new project from this template:
#   1. Renames the prefix throughout the solution (rename-project.sh).
#   2. Trims to a single DB provider (select-db-provider.sh).
#   3. Generates a JWT signing key and stores it via 'dotnet user-secrets'
#      (skip with --no-jwt-secret).
#   4. Writes a .env file at the repo root for Docker Compose
#      (skip with --no-env-file).
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
NO_ENV_FILE=false

usage() {
    sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
        --no-env-file)                NO_ENV_FILE=true; shift ;;
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
echo "  .env file:     $($NO_ENV_FILE && echo "skipped" || echo "write at repo root")"
echo ""
echo "  Step 1/4: scripts/rename-project.sh"
echo "  Step 2/4: scripts/select-db-provider.sh (with --force, since rename leaves tree dirty)"
$NO_JWT_SECRET || echo "  Step 3/4: dotnet user-secrets set Jwt:SecretKey (auto-generated)"
$NO_ENV_FILE   || echo "  Step 4/4: Write .env file for Docker (skip with --no-env-file)"
echo ""

if ! $FORCE; then
    confirm "Continue?" || { echo "Aborted by user." >&2; exit 1; }
fi

# ── Phase 4: Rename ────────────────────────────────────────────────────────

echo ""
echo ">>> [1/4] Running rename-project.sh..."
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
echo ">>> [2/4] Running select-db-provider.sh..."
echo ""

trim_args=(--provider "$PROVIDER" --prefix "$NEW_PREFIX" --force)
$SKIP_BUILD && trim_args+=(--skip-build)
$NO_BACKUP_BRANCH && trim_args+=(--no-backup-branch)

bash "$SCRIPT_DIR/select-db-provider.sh" "${trim_args[@]}"

# ── Phase 6: JWT signing key ───────────────────────────────────────────────

if ! $NO_JWT_SECRET; then
    echo ""
    echo ">>> [3/4] Generating JWT signing key..."
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

# ── Phase 7: Write .env file (Docker) ─────────────────────────────────────

ENV_WRITTEN=false
if ! $NO_ENV_FILE; then
    echo ""
    echo ">>> [4/4] Writing .env file..."
    echo ""

    ENV_PATH="$ROOT_DIR/.env"
    if [[ -f "$ENV_PATH" ]]; then
        echo "WARNING: Skipping .env: file already exists at $ENV_PATH"
    else
        # Restrictive umask so the secret file is never world/group-readable
        # between create and chmod. set -C makes the redirect atomic-fail if
        # another process raced us to create the file.
        ( umask 077 && set -C && : > "$ENV_PATH" ) || {
            echo "ERROR: Could not create $ENV_PATH (file already exists or permission denied)" >&2
            exit 1
        }

        # Generate a fresh JWT secret for .env; user-secrets (Phase 6) and Docker are
        # separate environments, so using independent keys is intentional.
        if command -v openssl >/dev/null 2>&1; then
            env_jwt="$(openssl rand -base64 48 | tr -d '\n')"
        else
            if [[ ! -r /dev/urandom ]]; then
                echo "ERROR: No entropy source available (openssl missing and /dev/urandom unreadable)" >&2
                rm -f "$ENV_PATH"
                exit 1
            fi
            env_jwt="$(head -c 48 /dev/urandom | base64 | tr -d '\n')"
        fi

        {
            printf 'JWT_SECRET_KEY=%s\n' "$env_jwt"
            printf 'CORS_ORIGIN=http://localhost:8080\n'
        } >> "$ENV_PATH"

        case "$PROVIDER" in
            PostgreSql)
                if command -v openssl >/dev/null 2>&1; then
                    pg_pwd="$(openssl rand -base64 24 | tr -d '\n')"
                else
                    pg_pwd="$(head -c 24 /dev/urandom | base64 | tr -d '\n')"
                fi
                printf 'POSTGRES_USER=starter\n'      >> "$ENV_PATH"
                printf 'POSTGRES_PASSWORD=%s\n' "$pg_pwd" >> "$ENV_PATH"
                printf 'POSTGRES_DB=starterdb\n'      >> "$ENV_PATH"
                ;;
            SqlServer)
                # SQL Server requires 8+ chars with 3 of 4 categories (upper/lower/digit/symbol).
                # Generate ~32 random base64 chars, then inject one of each required category
                # at randomized positions so entropy is preserved without a predictable prefix.
                if command -v openssl >/dev/null 2>&1; then
                    base_pwd="$(openssl rand -base64 24 | tr -d '\n=')"
                else
                    base_pwd="$(head -c 24 /dev/urandom | base64 | tr -d '\n=')"
                fi
                # Pick one char from each required category (RANDOM is 0..32767 => mod is fine for small alphabets).
                upper_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                lower_chars='abcdefghijklmnopqrstuvwxyz'
                digit_chars='0123456789'
                symbol_chars='!@#%^*-_+='
                pick() { local s="$1"; printf '%s' "${s:$((RANDOM % ${#s})):1}"; }
                extras="$(pick "$upper_chars")$(pick "$lower_chars")$(pick "$digit_chars")$(pick "$symbol_chars")"
                # Insert each extra char at a random position in base_pwd (Fisher-Yates-ish).
                sa_pwd="$base_pwd"
                for i in 0 1 2 3; do
                    pos=$((RANDOM % (${#sa_pwd} + 1)))
                    sa_pwd="${sa_pwd:0:$pos}${extras:$i:1}${sa_pwd:$pos}"
                done
                printf 'MSSQL_SA_PASSWORD=%s\n' "$sa_pwd" >> "$ENV_PATH"
                ;;
            # Sqlite: no extra keys needed.
        esac

        chmod 600 "$ENV_PATH"
        echo "Wrote .env (gitignored). Run: docker compose up"
        ENV_WRITTEN=true
    fi
fi

# ── Phase 8: Done ──────────────────────────────────────────────────────────

echo ""
echo "=== init-project complete ==="
echo "  Renamed:  $OLD_PREFIX -> $NEW_PREFIX"
echo "  Provider: $PROVIDER"
$NO_JWT_SECRET || echo "  JWT key:  set in user-secrets"
$ENV_WRITTEN   && echo "  .env:     written at repo root"
echo ""
echo "Next:"
echo "  - Review staged diff: git diff --cached"
echo "  - Commit when ready:  git commit -m 'chore: bootstrap $NEW_PREFIX with $PROVIDER provider'"
echo "  - Run app:            dotnet run --project src/Host/$NEW_PREFIX.WebApi"
echo ""
