#!/usr/bin/env bash
# Usage: ./scripts/rename-project.sh <NewPrefix> [OldPrefix] [--skip-build]
# Example: ./scripts/rename-project.sh Acme
# Example: ./scripts/rename-project.sh Contoso Acme --skip-build
#
# Renames the project prefix throughout the entire solution (namespaces, folders, files, config).
# Designed for bootstrapping a new project from this template.

set -euo pipefail

# ── Parse arguments ─────────────────────────────────────────────────────────

NEW_PREFIX="${1:?Usage: rename-project.sh <NewPrefix> [OldPrefix] [--skip-build]}"
OLD_PREFIX="${2:-Starter}"
SKIP_BUILD=false

# Check if second arg is --skip-build (no old prefix provided)
if [[ "$OLD_PREFIX" == "--skip-build" ]]; then
    OLD_PREFIX="Starter"
    SKIP_BUILD=true
fi

# Check for --skip-build in remaining args
for arg in "${@:3}"; do
    if [[ "$arg" == "--skip-build" ]]; then
        SKIP_BUILD=true
    fi
done

# ── Phase 0: Validate & Pre-flight ─────────────────────────────────────────

if [[ ! "$NEW_PREFIX" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Error: Invalid prefix '$NEW_PREFIX'. Must be a valid C# identifier." >&2
    exit 1
fi

if [[ "$NEW_PREFIX" == "$OLD_PREFIX" ]]; then
    echo "Error: New prefix '$NEW_PREFIX' is the same as old prefix '$OLD_PREFIX'." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SLNX_FILE="$ROOT_DIR/$OLD_PREFIX.WebApi.slnx"
if [[ ! -f "$SLNX_FILE" ]]; then
    echo "Error: Solution file not found: $SLNX_FILE" >&2
    exit 1
fi

NEW_PREFIX_LOWER="$(echo "$NEW_PREFIX" | tr '[:upper:]' '[:lower:]')"
OLD_PREFIX_LOWER="$(echo "$OLD_PREFIX" | tr '[:upper:]' '[:lower:]')"

echo ""
echo "=== Project Rename: '$OLD_PREFIX' -> '$NEW_PREFIX' ==="
echo "  Solution root: $ROOT_DIR"
echo ""

# Warn if git working tree is dirty
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null || true)" ]]; then
    echo "WARNING: Git working tree has uncommitted changes."
    echo "  Consider committing or stashing before renaming."
    echo ""
fi

# ── Phase 1: Clean build artifacts ─────────────────────────────────────────

echo "[Phase 1] Cleaning build artifacts..."

find "$ROOT_DIR/src" "$ROOT_DIR/tests" -type d \( -name bin -o -name obj \) -exec rm -rf {} + 2>/dev/null || true

if [[ -d "$ROOT_DIR/.vs" ]]; then
    rm -rf "$ROOT_DIR/.vs"
    echo "  Deleted: .vs/"
fi

echo "  Build artifacts cleaned."
echo ""

# ── Phase 2: Replace file contents ────────────────────────────────────────

echo "[Phase 2] Replacing file contents..."

FILES_MODIFIED=0

# Build find command with included extensions and excluded directories
while IFS= read -r -d '' file; do
    original_hash="$(md5sum "$file" | cut -d' ' -f1)"

    # Pass 1: PascalCase replacement
    sed -i "s/${OLD_PREFIX}/${NEW_PREFIX}/g" "$file"

    # Pass 2: Lowercase replacement (only if different from PascalCase)
    if [[ "$OLD_PREFIX_LOWER" != "$OLD_PREFIX" ]]; then
        sed -i "s/${OLD_PREFIX_LOWER}/${NEW_PREFIX_LOWER}/g" "$file"
    fi

    new_hash="$(md5sum "$file" | cut -d' ' -f1)"
    if [[ "$original_hash" != "$new_hash" ]]; then
        rel_path="${file#"$ROOT_DIR"/}"
        echo "  Updated: $rel_path"
        FILES_MODIFIED=$((FILES_MODIFIED + 1))
    fi
done < <(find "$ROOT_DIR" \
    -type f \
    \( -name '*.cs' -o -name '*.csproj' -o -name '*.slnx' -o -name '*.json' -o -name '*.ps1' -o -name '*.sh' -o -name '*.md' \) \
    -not -path "$ROOT_DIR/.git/*" \
    -not -path "$ROOT_DIR/.vs/*" \
    -not -path "$ROOT_DIR/.planning/*" \
    -not -path "$ROOT_DIR/.claude/*" \
    -not -path '*/bin/*' \
    -not -path '*/obj/*' \
    -print0)

echo "  $FILES_MODIFIED file(s) modified."
echo ""

# ── Phase 3: Rename .csproj files ─────────────────────────────────────────

echo "[Phase 3] Renaming .csproj files..."

CSPROJS_RENAMED=0

while IFS= read -r -d '' csproj; do
    dir="$(dirname "$csproj")"
    old_name="$(basename "$csproj")"
    new_name="${old_name//$OLD_PREFIX/$NEW_PREFIX}"
    if [[ "$old_name" != "$new_name" ]]; then
        mv "$csproj" "$dir/$new_name"
        echo "  $old_name -> $new_name"
        CSPROJS_RENAMED=$((CSPROJS_RENAMED + 1))
    fi
done < <(find "$ROOT_DIR/src" "$ROOT_DIR/tests" -name "*.csproj" -print0 2>/dev/null)

echo "  $CSPROJS_RENAMED .csproj file(s) renamed."
echo ""

# ── Phase 4: Rename project directories ──────────────────────────────────

echo "[Phase 4] Renaming project directories..."

DIRS_RENAMED=0

for parent in src tests; do
    parent_path="$ROOT_DIR/$parent"
    [[ -d "$parent_path" ]] || continue

    # Process directories (immediate children only)
    for dir in "$parent_path"/${OLD_PREFIX}*/; do
        [[ -d "$dir" ]] || continue
        old_name="$(basename "$dir")"
        new_name="${old_name//$OLD_PREFIX/$NEW_PREFIX}"
        if [[ "$old_name" != "$new_name" ]]; then
            mv "$dir" "$parent_path/$new_name"
            echo "  $old_name -> $new_name"
            DIRS_RENAMED=$((DIRS_RENAMED + 1))
        fi
    done
done

echo "  $DIRS_RENAMED director(ies) renamed."
echo ""

# ── Phase 5: Rename .slnx file ───────────────────────────────────────────

echo "[Phase 5] Renaming solution file..."

OLD_SLNX_NAME="$OLD_PREFIX.WebApi.slnx"
NEW_SLNX_NAME="$NEW_PREFIX.WebApi.slnx"
OLD_SLNX_PATH="$ROOT_DIR/$OLD_SLNX_NAME"

if [[ -f "$OLD_SLNX_PATH" ]]; then
    mv "$OLD_SLNX_PATH" "$ROOT_DIR/$NEW_SLNX_NAME"
    echo "  $OLD_SLNX_NAME -> $NEW_SLNX_NAME"
else
    echo "  Solution file '$OLD_SLNX_NAME' not found (may have been renamed already)."
fi

echo ""

# ── Phase 6: Verification ────────────────────────────────────────────────

echo "=== Summary ==="
echo "  Files modified:      $FILES_MODIFIED"
echo "  .csproj renamed:     $CSPROJS_RENAMED"
echo "  Directories renamed: $DIRS_RENAMED"
echo "  Solution file:       $OLD_SLNX_NAME -> $NEW_SLNX_NAME"
echo ""

if [[ "$SKIP_BUILD" == false ]]; then
    echo "[Phase 6] Running verification build..."
    dotnet build "$ROOT_DIR/$NEW_SLNX_NAME"
    echo ""
    echo "Build succeeded!"
else
    echo "Build skipped (--skip-build)."
fi

echo ""
echo "=== Rename complete! ==="
echo ""
echo "Post-rename checklist:"
echo "  1. Delete old SQLite database if it exists (e.g., ${OLD_PREFIX_LOWER}.db)"
echo "  2. Update user secrets ID if using 'dotnet user-secrets'"
echo "  3. Close and reopen your IDE to refresh caches"
echo ""
