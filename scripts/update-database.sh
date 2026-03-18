#!/usr/bin/env bash
# Usage: ./scripts/update-database.sh <Provider> [MigrationName]
# Example: ./scripts/update-database.sh Sqlite
# Example: ./scripts/update-database.sh Sqlite InitialCreate  (apply up to specific migration)
#
# Wraps 'dotnet ef database update' with the correct --project and --startup-project
# flags for each database provider's migration assembly.

set -euo pipefail

PROVIDER="${1:?Usage: update-database.sh <Sqlite|SqlServer|PostgreSql> [MigrationName]}"
MIGRATION_NAME="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

case "$PROVIDER" in
    Sqlite)     PROJECT="src/Starter.Data.Migrations.Sqlite" ;;
    SqlServer)  PROJECT="src/Starter.Data.Migrations.SqlServer" ;;
    PostgreSql) PROJECT="src/Starter.Data.Migrations.PostgreSql" ;;
    *)          echo "Error: Unknown provider '$PROVIDER'. Use: Sqlite, SqlServer, PostgreSql" >&2; exit 1 ;;
esac

echo "Updating database for provider '$PROVIDER'..."

ARGS=(
    --startup-project "$ROOT_DIR/src/Starter.WebApi"
    --project "$ROOT_DIR/$PROJECT"
)

export Database__Provider="$PROVIDER"

if [ -n "$MIGRATION_NAME" ]; then
    dotnet ef database update "$MIGRATION_NAME" "${ARGS[@]}"
else
    dotnet ef database update "${ARGS[@]}"
fi

echo "Database updated successfully for $PROVIDER."
