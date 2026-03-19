#!/usr/bin/env bash
#
# Tests that each module can be independently removed from the solution.
#
# For each removable module:
# 1. Comments out its using statements in Program.cs
# 2. Comments out its extension method calls in Program.cs
# 3. Removes its ProjectReference from Starter.WebApi.csproj
# 4. Optionally renames dependent controllers to .bak
# 5. Runs dotnet build
# 6. Restores all files via git checkout
#
# Usage:
#   bash test-module-removal.sh
#   bash test-module-removal.sh --module Starter.Cors

set -euo pipefail

# Parse arguments
SINGLE_MODULE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --module)
            SINGLE_MODULE="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Determine solution root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOLUTION_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PROGRAM_CS="$SOLUTION_ROOT/src/Starter.WebApi/Program.cs"
CSPROJ="$SOLUTION_ROOT/src/Starter.WebApi/Starter.WebApi.csproj"
CONTROLLERS_DIR="$SOLUTION_ROOT/src/Starter.WebApi/Controllers"

if [[ ! -f "$PROGRAM_CS" ]]; then
    echo "ERROR: Program.cs not found at $PROGRAM_CS"
    exit 1
fi

# Cleanup function -- always restore files
cleanup() {
    git checkout -- "$PROGRAM_CS" "$CSPROJ" 2>/dev/null || true
    git checkout -- "$CONTROLLERS_DIR/" 2>/dev/null || true
    # Restore any .bak files
    for bak in "$CONTROLLERS_DIR"/*.cs.bak; do
        if [[ -f "$bak" ]]; then
            local orig="${bak%.bak}"
            mv -f "$bak" "$orig"
        fi
    done
}
trap cleanup EXIT

PASSED=0
FAILED=0
FAILED_MODULES=()

# Module definitions as pipe-delimited records:
# Name|Usings(comma-separated)|Calls(comma-separated)|Controllers(comma-separated)
MODULES=(
    # Tier 1: Pure infrastructure
    "Starter.ExceptionHandling|using Starter.ExceptionHandling;|AddAppExceptionHandling,UseAppExceptionHandling|"
    "Starter.Logging|using Serilog;,using Starter.Logging;|AddAppLogging,UseAppRequestLogging,Log.Logger,Log.Information,Log.Fatal,Log.CloseAndFlush,LoggerConfiguration,CreateBootstrapLogger,Bootstrap Logger,full Serilog pipeline,.MinimumLevel,.WriteTo.Console|"
    "Starter.Cors|using Starter.Cors;|AddAppCors|"
    "Starter.OpenApi|using Starter.OpenApi;|AddAppOpenApi,UseAppOpenApi|"
    "Starter.RateLimiting|using Starter.RateLimiting;|AddAppRateLimiting,UseAppRateLimiting|"
    "Starter.Compression|using Starter.Compression;||"
    "Starter.HealthChecks|using Starter.HealthChecks;|AddAppHealthChecks,UseAppHealthChecks|"
    "Starter.Versioning|using Starter.Versioning;|AddAppVersioning|AuthController.cs,TodoController.cs,TodoV2Controller.cs,CacheDemoController.cs"
    "Starter.Validation|using Starter.Validation;|AddAppValidation|"
    "Starter.Auth.Google|using Starter.Auth.Google;|AddAppGoogle|"
    "Starter.Data|using Starter.Data;|AddAppData,UseAppData|"
    "Starter.Data.Migrations.Sqlite|||"
    "Starter.Data.Migrations.SqlServer|||"
    "Starter.Data.Migrations.PostgreSql|||"
    # Tier 2: With controller dependencies
    "Starter.Auth.Shared|using Starter.Auth.Shared;,using Starter.Auth.Identity;,using Starter.Auth.Jwt;,using Starter.Auth.Google;|AddAppAuthShared,AddAppIdentity,AddAppJwt,AddAppGoogle|AuthController.cs"
    "Starter.Auth.Identity|using Starter.Auth.Identity;|AddAppIdentity|AuthController.cs"
    "Starter.Auth.Jwt|using Starter.Auth.Jwt;|AddAppJwt|AuthController.cs"
    "Starter.Caching|using Starter.Caching;|AddAppCaching|CacheDemoController.cs"
    "Starter.Responses|using Starter.Responses;|AddAppResponses|TodoController.cs"
)

echo ""
echo "========================================"
echo "  Module Removal Smoke Tests"
echo "  Testing ${#MODULES[@]} module(s)"
echo "========================================"
echo ""

for entry in "${MODULES[@]}"; do
    IFS='|' read -r MOD_NAME MOD_USINGS MOD_CALLS MOD_CONTROLLERS <<< "$entry"

    # Filter to single module if specified
    if [[ -n "$SINGLE_MODULE" && "$MOD_NAME" != "$SINGLE_MODULE" ]]; then
        continue
    fi

    printf "Testing removal of: %-40s" "$MOD_NAME"

    # Read current files
    cp "$PROGRAM_CS" "$PROGRAM_CS.bak"
    cp "$CSPROJ" "$CSPROJ.bak"

    RENAMED_CONTROLLERS=()

    # 1. Comment out using statements
    if [[ -n "$MOD_USINGS" ]]; then
        IFS=',' read -ra USINGS <<< "$MOD_USINGS"
        for using_stmt in "${USINGS[@]}"; do
            # Escape special characters for sed and comment out the line
            escaped=$(printf '%s\n' "$using_stmt" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
            sed -i "s/^\\(\\s*\\)\\(${escaped}\\)/\\1\\/\\/ \\2/" "$PROGRAM_CS"
        done
    fi

    # 2. Comment out extension calls
    if [[ -n "$MOD_CALLS" ]]; then
        IFS=',' read -ra CALLS <<< "$MOD_CALLS"
        for call in "${CALLS[@]}"; do
            # Escape special regex characters in the call pattern for sed
            escaped_call=$(printf '%s\n' "$call" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
            # Comment out lines containing the call (only if not already commented)
            sed -i "/^[[:space:]]*\\/\\//! s/^\\(\\s*\\)\\(.*${escaped_call}.*\\)$/\\1\\/\\/ \\2/" "$PROGRAM_CS"
        done
    fi

    # 3. Remove ProjectReference from csproj
    escaped_name=$(printf '%s\n' "$MOD_NAME" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
    sed -i "/${escaped_name}/d" "$CSPROJ"

    # 4. Rename controllers
    if [[ -n "$MOD_CONTROLLERS" ]]; then
        IFS=',' read -ra CONTROLLERS <<< "$MOD_CONTROLLERS"
        for ctrl in "${CONTROLLERS[@]}"; do
            ctrl_path="$CONTROLLERS_DIR/$ctrl"
            if [[ -f "$ctrl_path" ]]; then
                mv "$ctrl_path" "$ctrl_path.bak"
                RENAMED_CONTROLLERS+=("$ctrl_path")
            fi
        done
    fi

    # 5. Run dotnet build
    BUILD_EXIT=0
    BUILD_OUTPUT=$(dotnet build "$SOLUTION_ROOT/src/Starter.WebApi" 2>&1) || BUILD_EXIT=$?

    if [[ $BUILD_EXIT -eq 0 ]]; then
        echo " -> PASSED"
        ((PASSED++))
    else
        echo " -> FAILED"
        ((FAILED++))
        FAILED_MODULES+=("$MOD_NAME")
        echo "  Build output (last 10 lines):"
        echo "$BUILD_OUTPUT" | tail -10 | sed 's/^/    /'
    fi

    # 6. Restore files
    mv -f "$PROGRAM_CS.bak" "$PROGRAM_CS"
    mv -f "$CSPROJ.bak" "$CSPROJ"
    for ctrl_path in "${RENAMED_CONTROLLERS[@]}"; do
        if [[ -f "$ctrl_path.bak" ]]; then
            mv -f "$ctrl_path.bak" "$ctrl_path"
        fi
    done
done

echo ""
echo "========================================"
echo "  Results"
echo "========================================"
echo "  Total:  $((PASSED + FAILED))"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
    echo ""
    echo "  Failed modules:"
    for fm in "${FAILED_MODULES[@]}"; do
        echo "    - $fm"
    done
fi

echo ""

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
