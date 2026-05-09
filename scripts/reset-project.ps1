<#
.SYNOPSIS
    Reverts the working tree to HEAD so the bootstrap scripts can be re-run from scratch.
.DESCRIPTION
    Companion to init-project.ps1. Wipes everything the init flow touches
    (renamed files, deleted migration projects, *.db, bin/obj, JWT user-secret)
    while preserving any in-progress edits under scripts/.

    Steps:
      1. Clears 'dotnet user-secrets' for the host project (using the current,
         possibly renamed csproj path so the active UserSecretsId is targeted).
      2. Stashes any in-progress edits under scripts/ so they survive the wipe.
      3. Runs 'git reset --hard HEAD' to revert tracked files.
      4. Runs 'git clean -fdx -e scripts' to wipe untracked + ignored files.
      5. Pops the stash to restore the script edits.

    Intended for iterative testing of the bootstrap scripts: run init-project,
    inspect the result, run reset-project, edit a script, repeat.
.PARAMETER Yes
    Skip the confirmation prompt.
.PARAMETER KeepSecrets
    Skip step 1 (leave the JWT user-secret in place).
.PARAMETER KeepDb
    Skip removal of *.db files (added to the clean exclude list).
.EXAMPLE
    ./scripts/reset-project.ps1
.EXAMPLE
    ./scripts/reset-project.ps1 -Yes
#>
param(
    [switch]$Yes,
    [switch]$KeepSecrets,
    [switch]$KeepDb
)

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot

function Confirm-Continue {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt [y/N]"
    return $ans -match '^(y|yes)$'
}

# ── Phase 0: Sanity checks ─────────────────────────────────────────────────

git -C $rootDir rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Not inside a git repository ($rootDir)."
}

$currentRef = (git -C $rootDir rev-parse --short HEAD 2>$null)
$branch     = (git -C $rootDir rev-parse --abbrev-ref HEAD 2>$null)
if ($branch -eq 'HEAD') {
    Write-Host "WARNING: detached HEAD at $currentRef. Reset will target this commit." -ForegroundColor Yellow
}

# ── Phase 1: Plan summary + confirm ────────────────────────────────────────

Write-Host ""
Write-Host "=== reset-project plan ===" -ForegroundColor Cyan
Write-Host "  Baseline:        $branch @ $currentRef"
Write-Host "  Clear secrets:   $(-not $KeepSecrets)"
Write-Host "  Wipe *.db:       $(-not $KeepDb)"
Write-Host "  Preserve:        scripts/ folder (working-tree edits stashed + popped)"
Write-Host ""
Write-Host "  Step 1/4: dotnet user-secrets clear (host csproj)"
Write-Host "  Step 2/4: git stash push -- scripts/   (only if dirty)"
Write-Host "  Step 3/4: git reset --hard HEAD"
$cleanLine = "  Step 4/4: git clean -fdx -e scripts"
if ($KeepDb) { $cleanLine += " -e *.db" }
Write-Host $cleanLine
Write-Host ""

if (-not $Yes) {
    if (-not (Confirm-Continue "This will discard ALL changes outside scripts/. Continue?")) {
        throw 'Aborted by user.'
    }
}

# ── Phase 2: Clear user-secrets (against the current/renamed csproj) ───────

Write-Host ""
if (-not $KeepSecrets) {
    Write-Host ">>> [1/4] Clearing dotnet user-secrets..." -ForegroundColor Green

    $hostCsproj = $null
    $hostDir = Join-Path $rootDir 'src/Host'
    if (Test-Path $hostDir) {
        $hostCsproj = Get-ChildItem -Path $hostDir -Recurse -Depth 2 -Filter '*.csproj' -ErrorAction SilentlyContinue |
                      Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $hostCsproj) {
        Write-Host "  No host csproj found under src/Host -- skipping."
    } elseif (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Host "  'dotnet' not on PATH -- skipping."
    } else {
        # 'clear' is a no-op when no UserSecretsId exists; tolerate failure.
        $null = dotnet user-secrets clear --project $hostCsproj 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Cleared secrets for $hostCsproj"
        } else {
            Write-Host "  No secrets to clear for $hostCsproj (or no UserSecretsId)."
        }
        $global:LASTEXITCODE = 0
    }
} else {
    Write-Host ">>> [1/4] Skipped (-KeepSecrets)." -ForegroundColor Green
}

# ── Phase 3: Stash scripts/ if dirty ───────────────────────────────────────

Write-Host ""
Write-Host ">>> [2/4] Stashing scripts/ edits (if any)..." -ForegroundColor Green

$stashed = $false
$dirtyScripts = git -C $rootDir status --porcelain -- scripts/
if ($dirtyScripts) {
    git -C $rootDir stash push --include-untracked -m 'reset-project-tmp' -- scripts/ | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git stash push failed (exit $LASTEXITCODE)."
    }
    $stashed = $true
    Write-Host "  Stashed scripts/ working-tree changes."
} else {
    Write-Host "  scripts/ already clean."
}

# ── Phase 4: Hard reset ────────────────────────────────────────────────────

Write-Host ""
Write-Host ">>> [3/4] git reset --hard HEAD..." -ForegroundColor Green
git -C $rootDir reset --hard HEAD
if ($LASTEXITCODE -ne 0) {
    throw "git reset --hard failed (exit $LASTEXITCODE)."
}

# ── Phase 5: Clean untracked + ignored ─────────────────────────────────────

Write-Host ""
Write-Host ">>> [4/4] git clean -fdx (excluding scripts/)..." -ForegroundColor Green

$cleanArgs = @('-fdx', '-e', 'scripts')
if ($KeepDb) { $cleanArgs += @('-e', '*.db') }

git -C $rootDir clean @cleanArgs
if ($LASTEXITCODE -ne 0) {
    throw "git clean failed (exit $LASTEXITCODE)."
}

# ── Phase 6: Restore scripts/ ──────────────────────────────────────────────

if ($stashed) {
    Write-Host ""
    Write-Host ">>> Restoring scripts/ edits from stash..." -ForegroundColor Green
    git -C $rootDir stash pop | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: 'git stash pop' did not apply cleanly." -ForegroundColor Yellow
        Write-Host "  Your scripts/ edits remain in 'git stash list' for manual recovery." -ForegroundColor Yellow
        throw "Stash pop failed."
    }
    Write-Host "  scripts/ edits restored."
}

# ── Phase 7: Done ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=== reset-project complete ===" -ForegroundColor Green
Write-Host "  Working tree reset to $branch @ $currentRef"
if (-not $KeepSecrets) { Write-Host "  user-secrets cleared (host csproj)" }
Write-Host "  scripts/ preserved"
Write-Host ""
Write-Host "Next: re-run ./scripts/init-project.ps1 to test changes." -ForegroundColor Yellow
Write-Host ""
