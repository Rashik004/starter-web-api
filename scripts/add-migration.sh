#!/usr/bin/env bash
# Usage: ./scripts/add-migration.sh <Provider> <MigrationName>
# Example: ./scripts/add-migration.sh Sqlite InitialCreate
#
# Wraps 'dotnet ef migrations add' with the correct --project and --startup-project
# flags for each database provider's migration assembly.

set -euo pipefail

PROVIDER="${1:?Usage: add-migration.sh <Sqlite|SqlServer|PostgreSql> <MigrationName>}"
MIGRATION_NAME="${2:?Usage: add-migration.sh <Sqlite|SqlServer|PostgreSql> <MigrationName>}"

# Resolve script directory to find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

case "$PROVIDER" in
    Sqlite)     PROJECT="src/Starter.Data.Migrations.Sqlite" ;;
    SqlServer)  PROJECT="src/Starter.Data.Migrations.SqlServer" ;;
    PostgreSql) PROJECT="src/Starter.Data.Migrations.PostgreSql" ;;
    *)          echo "Error: Unknown provider '$PROVIDER'. Use: Sqlite, SqlServer, PostgreSql" >&2; exit 1 ;;
esac

echo "Adding migration '$MIGRATION_NAME' for provider '$PROVIDER'..."
echo "  Migration project: $PROJECT"
echo "  Startup project:   src/Starter.WebApi"

Database__Provider="$PROVIDER" dotnet ef migrations add "$MIGRATION_NAME" \
    --startup-project "$ROOT_DIR/src/Starter.WebApi" \
    --project "$ROOT_DIR/$PROJECT"

echo "Migration '$MIGRATION_NAME' added successfully for $PROVIDER."
