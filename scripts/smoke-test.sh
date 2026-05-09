#!/usr/bin/env bash
# Usage: ./scripts/smoke-test.sh [init-project args...]
# Example: ./scripts/smoke-test.sh --prefix Acme --provider Sqlite --skip-build --no-backup-branch
# Example: ./scripts/smoke-test.sh --prefix Acme --provider PostgreSql --skip-build --no-backup-branch --force
#
# Smoke-tests the bootstrap flow:
#   1. Runs scripts/init-project.sh, forwarding all caller args.
#   2. If init succeeds, runs scripts/reset-project.sh --yes to revert.
#   3. Prompts whether to loop and run again with the same args.
#
# If init-project fails, the dirty working tree is left in place for
# inspection -- reset is NOT auto-invoked.
#
# Tip: pass --force --skip-build --no-backup-branch to init for a fast
# unattended cycle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Surface --help before forwarding so we don't trigger init's own usage twice.
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
    esac
done

INIT_ARGS=("$@")

confirm() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

cycle=1
while true; do
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo " smoke-test cycle #$cycle"
    echo "════════════════════════════════════════════════════════════"

    echo ""
    echo ">>> init-project.sh ${INIT_ARGS[*]}"
    if bash "$SCRIPT_DIR/init-project.sh" "${INIT_ARGS[@]}"; then
        init_status="OK"
    else
        init_status="FAIL ($?)"
        echo ""
        echo "✗ init-project failed -- leaving dirty tree for inspection." >&2
        echo "  Run scripts/reset-project.sh manually when ready." >&2
        exit 1
    fi

    echo ""
    echo ">>> init result: $init_status"
    echo ""
    echo ">>> reset-project.sh --yes"
    bash "$SCRIPT_DIR/reset-project.sh" --yes

    echo ""
    echo "✓ cycle #$cycle complete (init=$init_status, reset=OK)"
    echo ""

    if ! confirm "Run another cycle with the same args?"; then
        echo "Done. $cycle cycle(s) executed."
        break
    fi

    cycle=$((cycle + 1))
done
