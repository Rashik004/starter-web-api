<#
.SYNOPSIS
    Smoke-tests the bootstrap flow: init-project, then reset-project, in a loop.
.DESCRIPTION
    Runs scripts/init-project.ps1 with the supplied arguments. On success,
    runs scripts/reset-project.ps1 -Yes to revert. Then prompts whether to
    loop with the same args.

    If init-project fails, the dirty working tree is left in place for
    inspection -- reset is NOT auto-invoked.

    All arguments are forwarded verbatim to init-project.ps1. Pass them with
    PowerShell-style flags (-Prefix Acme -Provider Sqlite ...).

    Tip: pass -Force -SkipBuild -NoBackupBranch for a fast unattended cycle.
.EXAMPLE
    ./scripts/smoke-test.ps1 -Prefix Acme -Provider Sqlite -SkipBuild -NoBackupBranch
.EXAMPLE
    ./scripts/smoke-test.ps1 -Prefix Acme -Provider PostgreSql -SkipBuild -NoBackupBranch -Force
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InitArgs
)

$ErrorActionPreference = 'Stop'

function Confirm-Continue {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt [y/N]"
    return $ans -match '^(y|yes)$'
}

$initScript  = Join-Path $PSScriptRoot 'init-project.ps1'
$resetScript = Join-Path $PSScriptRoot 'reset-project.ps1'

$cycle = 1
while ($true) {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " smoke-test cycle #$cycle" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    Write-Host ""
    Write-Host ">>> init-project.ps1 $($InitArgs -join ' ')" -ForegroundColor Green

    $initOk = $true
    try {
        & $initScript @InitArgs
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { $initOk = $false }
    } catch {
        $initOk = $false
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    if (-not $initOk) {
        Write-Host ""
        Write-Host "✗ init-project failed -- leaving dirty tree for inspection." -ForegroundColor Red
        Write-Host "  Run scripts/reset-project.ps1 manually when ready." -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Host ">>> reset-project.ps1 -Yes" -ForegroundColor Green
    & $resetScript -Yes
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        throw "reset-project.ps1 failed (exit $LASTEXITCODE)."
    }

    Write-Host ""
    Write-Host "✓ cycle #$cycle complete (init=OK, reset=OK)" -ForegroundColor Green
    Write-Host ""

    if (-not (Confirm-Continue "Run another cycle with the same args?")) {
        Write-Host "Done. $cycle cycle(s) executed."
        break
    }

    $cycle++
}
