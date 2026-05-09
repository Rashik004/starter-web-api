#!/usr/bin/env bash
# Usage: ./scripts/reset-project.sh [--yes] [--keep-secrets] [--keep-db]
# Example: ./scripts/reset-project.sh
# Example: ./scripts/reset-project.sh --yes
#
# Reverts the working tree to HEAD (the canonical template state) so the
# bootstrap scripts (init-project, rename-project, select-db-provider) can
# be re-run from scratch. Intended for iterative testing of those scripts.
#
# What it does:
#   1. Clears 'dotnet user-secrets' for the host project (using the current,
#      possibly renamed csproj path so the active UserSecretsId is targeted).
#   2. Stashes any in-progress edits under scripts/ so they survive the wipe.
#   3. Runs 'git reset --hard HEAD' to revert tracked files (renames,
#      content edits, deleted migration projects, etc.).
#   4. Runs 'git clean -fdx -e scripts' to wipe untracked + ignored files
#      (bin/, obj/, *.db, .vs/, ...). The scripts/ folder is excluded.
#   5. Pops the stash to restore the script edits.
#
# Flags:
#   --yes / -y       Skip the confirmation prompt.
#   --keep-secrets   Skip step 1 (leave the JWT user-secret in place).
#   --keep-db        Skip removal of *.db files (added to the clean exclude).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse arguments ─────────────────────────────────────────────────────────

ASSUME_YES=false
KEEP_SECRETS=false
KEEP_DB=false

usage() {
    sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)        ASSUME_YES=true; shift ;;
        --keep-secrets)  KEEP_SECRETS=true; shift ;;
        --keep-db)       KEEP_DB=true; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

# ── Helpers ────────────────────────────────────────────────────────────────

confirm() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

# ── Phase 0: Sanity checks ─────────────────────────────────────────────────

if ! git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not inside a git repository ($ROOT_DIR)." >&2
    exit 1
fi

CURRENT_REF="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")"
BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
if [[ "$BRANCH" == "HEAD" ]]; then
    echo "WARNING: detached HEAD at $CURRENT_REF. Reset will target this commit." >&2
fi

# ── Phase 1: Plan summary + confirm ────────────────────────────────────────

echo ""
echo "=== reset-project plan ==="
echo "  Baseline:        $BRANCH @ $CURRENT_REF"
echo "  Clear secrets:   $(! $KEEP_SECRETS && echo true || echo false)"
echo "  Wipe *.db:       $(! $KEEP_DB && echo true || echo false)"
echo "  Preserve:        scripts/ folder (working-tree edits stashed + popped)"
echo ""
echo "  Step 1/4: dotnet user-secrets clear (host csproj)"
echo "  Step 2/4: git stash push -- scripts/   (only if dirty)"
echo "  Step 3/4: git reset --hard HEAD"
echo "  Step 4/4: git clean -fdx -e scripts$($KEEP_DB && echo " -e *.db" || true)"
echo ""

if ! $ASSUME_YES; then
    confirm "This will discard ALL changes outside scripts/. Continue?" \
        || { echo "Aborted by user." >&2; exit 1; }
fi

# ── Phase 2: Clear user-secrets (against the current/renamed csproj) ───────

if ! $KEEP_SECRETS; then
    echo ""
    echo ">>> [1/4] Clearing dotnet user-secrets..."

    HOST_CSPROJ=""
    if [[ -d "$ROOT_DIR/src/Host" ]]; then
        HOST_CSPROJ="$(find "$ROOT_DIR/src/Host" -maxdepth 3 -name '*.csproj' -print -quit 2>/dev/null || true)"
    fi

    if [[ -z "$HOST_CSPROJ" ]]; then
        echo "  No host csproj found under src/Host -- skipping."
    elif ! command -v dotnet >/dev/null 2>&1; then
        echo "  'dotnet' not on PATH -- skipping."
    else
        # 'clear' is a no-op when no UserSecretsId exists; tolerate the error.
        dotnet user-secrets clear --project "$HOST_CSPROJ" >/dev/null 2>&1 \
            && echo "  Cleared secrets for $HOST_CSPROJ" \
            || echo "  No secrets to clear for $HOST_CSPROJ (or no UserSecretsId)."
    fi
else
    echo ""
    echo ">>> [1/4] Skipped (--keep-secrets)."
fi

# ── Phase 3: Stash scripts/ if dirty ───────────────────────────────────────

echo ""
echo ">>> [2/4] Stashing scripts/ edits (if any)..."

STASHED=false
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain -- scripts/ 2>/dev/null)" ]]; then
    git -C "$ROOT_DIR" stash push --include-untracked \
        -m "reset-project-tmp" -- scripts/ >/dev/null
    STASHED=true
    echo "  Stashed scripts/ working-tree changes."
else
    echo "  scripts/ already clean."
fi

# ── Phase 4: Hard reset ────────────────────────────────────────────────────

echo ""
echo ">>> [3/4] git reset --hard HEAD..."
git -C "$ROOT_DIR" reset --hard HEAD

# ── Phase 5: Clean untracked + ignored ─────────────────────────────────────

echo ""
echo ">>> [4/4] git clean -fdx (excluding scripts/)..."

clean_args=(-fdx -e scripts)
$KEEP_DB && clean_args+=(-e '*.db')

git -C "$ROOT_DIR" clean "${clean_args[@]}"

# ── Phase 6: Restore scripts/ ──────────────────────────────────────────────

if $STASHED; then
    echo ""
    echo ">>> Restoring scripts/ edits from stash..."
    if ! git -C "$ROOT_DIR" stash pop >/dev/null 2>&1; then
        echo "WARNING: 'git stash pop' did not apply cleanly." >&2
        echo "  Your scripts/ edits remain in 'git stash list' for manual recovery." >&2
        exit 1
    fi
    echo "  scripts/ edits restored."
fi

# ── Phase 7: Done ──────────────────────────────────────────────────────────

echo ""
echo "=== reset-project complete ==="
echo "  Working tree reset to $BRANCH @ $CURRENT_REF"
$KEEP_SECRETS || echo "  user-secrets cleared (host csproj)"
echo "  scripts/ preserved"
echo ""
echo "Next: re-run ./scripts/init-project.sh to test changes."
echo ""
