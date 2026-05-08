<#
.SYNOPSIS
    Bootstraps a new project from this template: renames the prefix, then trims to a single DB provider.
.DESCRIPTION
    Thin orchestrator that calls 'rename-project.ps1' followed by 'select-db-provider.ps1'.

    Performs its own dirty-tree pushback up front (matching select-db-provider's pattern),
    then always passes '-Force' to select-db-provider because the working tree is necessarily
    dirty after the rename phase. The new prefix is forwarded to select-db-provider via
    '-Prefix' so it doesn't auto-detect.
.PARAMETER NewPrefix
    New project prefix (e.g., 'Acme', 'Acme.Server'). Prompted if omitted.
.PARAMETER OldPrefix
    Existing prefix to replace. Defaults to 'Starter'.
.PARAMETER Provider
    DB provider to keep: Sqlite, SqlServer, or PostgreSql. Prompted if omitted.
.PARAMETER Force
    Skip the dirty-tree pushback.
.PARAMETER SkipBuild
    Forwarded to BOTH child scripts (no verification builds).
.PARAMETER NoBackupBranch
    Forwarded to select-db-provider only.
.PARAMETER IncludeBootstrapScripts
    If set, the rename phase rewrites the bootstrap scripts themselves
    (init-project, rename-project, select-db-provider .ps1/.sh). Default: skip them
    so the template stays reusable. If neither this nor its inverse is passed,
    the orchestrator prompts (default Y = skip).
.EXAMPLE
    ./scripts/init-project.ps1 -NewPrefix Acme -Provider Sqlite
.EXAMPLE
    ./scripts/init-project.ps1 -NewPrefix Acme -OldPrefix Starter -Provider PostgreSql -Force
.EXAMPLE
    ./scripts/init-project.ps1
#>
param(
    [string]$NewPrefix,
    [string]$OldPrefix = 'Starter',
    [ValidateSet('Sqlite', 'SqlServer', 'PostgreSql')]
    [string]$Provider,
    [switch]$Force,
    [switch]$SkipBuild,
    [switch]$NoBackupBranch,
    [switch]$IncludeBootstrapScripts
)

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot

function Confirm-Continue {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt [y/N]"
    return $ans -match '^(y|yes)$'
}

# ── Phase 0: Collect & validate inputs ─────────────────────────────────────

if (-not $NewPrefix) {
    $NewPrefix = Read-Host "Enter new project prefix (e.g., 'Acme' or 'Acme.Server')"
}

if ($NewPrefix -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$') {
    throw "Invalid prefix '$NewPrefix'. Must be a C# identifier or dotted namespace (e.g., 'Acme' or 'Acme.Server'). Hyphens are not allowed."
}

if ($NewPrefix -eq $OldPrefix) {
    throw "New prefix '$NewPrefix' is the same as old prefix '$OldPrefix'. Nothing to do."
}

$slnxFile = Join-Path $rootDir "src\$OldPrefix.WebApi.slnx"
if (-not (Test-Path $slnxFile)) {
    throw "Solution file not found: $slnxFile. Are you running from the correct repo, or has the project already been renamed?"
}

# ── Phase 1: Dirty-tree pushback (matching select-db-provider) ─────────────

if (-not $Force) {
    $dirty = git -C $rootDir status --porcelain
    if ($dirty) {
        Write-Host "Git working tree is dirty:" -ForegroundColor Yellow
        Write-Host $dirty
        if (-not (Confirm-Continue "Proceed anyway?")) {
            throw 'Aborted: commit or stash your changes first, or pass -Force.'
        }
    }
}

# ── Phase 2: Prompt for provider if missing ────────────────────────────────

if (-not $Provider) {
    Write-Host ""
    Write-Host "Select the database provider to keep:" -ForegroundColor Cyan
    Write-Host "  1) SqlServer  (default)"
    Write-Host "  2) Sqlite     (file-based)"
    Write-Host "  3) PostgreSql"
    $choice = Read-Host "Choice [1-3] (default: 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
    $Provider = switch ($choice) {
        '1' { 'SqlServer' }
        '2' { 'Sqlite' }
        '3' { 'PostgreSql' }
        default { throw "Invalid choice: $choice" }
    }
}

# ── Phase 2b: Resolve bootstrap-script handling ────────────────────────────

if ($PSBoundParameters.ContainsKey('IncludeBootstrapScripts')) {
    $skipBootstrap = -not $IncludeBootstrapScripts.IsPresent
} else {
    Write-Host ""
    Write-Host "Skip bootstrap scripts during content replacement?" -ForegroundColor Cyan
    Write-Host "  (init-project, rename-project, select-db-provider .ps1/.sh)"
    $ans = Read-Host "Skip them? [Y/n]"
    $skipBootstrap = -not ($ans -match '^(n|no)$')
}

# ── Phase 3: Combined plan summary ─────────────────────────────────────────

Write-Host ""
Write-Host "=== init-project plan ===" -ForegroundColor Cyan
Write-Host "  Rename:        $OldPrefix -> $NewPrefix"
Write-Host "  Provider:      keep $Provider (drop the others)"
Write-Host "  SkipBuild:     $SkipBuild"
Write-Host "  Backup br.:    $(-not $NoBackupBranch)"
Write-Host "  Skip bootstr.: $skipBootstrap"
Write-Host ""
Write-Host "  Step 1/2: scripts/rename-project.ps1"
Write-Host "  Step 2/2: scripts/select-db-provider.ps1 (with -Force, since rename leaves tree dirty)"
Write-Host ""

if (-not $Force) {
    if (-not (Confirm-Continue "Continue?")) { throw 'Aborted by user.' }
}

# ── Phase 4: Rename ────────────────────────────────────────────────────────

Write-Host ""
Write-Host ">>> [1/2] Running rename-project.ps1..." -ForegroundColor Green
Write-Host ""

$renameArgs = @{
    NewPrefix               = $NewPrefix
    OldPrefix               = $OldPrefix
    IncludeBootstrapScripts = (-not $skipBootstrap)
}
if ($SkipBuild) { $renameArgs['SkipBuild'] = $true }

& (Join-Path $PSScriptRoot 'rename-project.ps1') @renameArgs
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    throw "rename-project.ps1 failed (exit $LASTEXITCODE). Aborting before DB trim."
}

# ── Phase 5: DB trim ───────────────────────────────────────────────────────

Write-Host ""
Write-Host ">>> [2/2] Running select-db-provider.ps1..." -ForegroundColor Green
Write-Host ""

$trimArgs = @{
    Provider = $Provider
    Prefix   = $NewPrefix
    Force    = $true   # tree is dirty after rename; suppress select-db's own pushback
}
if ($SkipBuild)      { $trimArgs['SkipBuild']      = $true }
if ($NoBackupBranch) { $trimArgs['NoBackupBranch'] = $true }

& (Join-Path $PSScriptRoot 'select-db-provider.ps1') @trimArgs
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    throw "select-db-provider.ps1 failed (exit $LASTEXITCODE). Rename succeeded; trim did not."
}

# ── Phase 6: Done ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=== init-project complete ===" -ForegroundColor Green
Write-Host "  Renamed:  $OldPrefix -> $NewPrefix"
Write-Host "  Provider: $Provider"
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  - Review staged diff: git diff --cached"
Write-Host "  - Commit when ready:  git commit -m 'chore: bootstrap $NewPrefix with $Provider provider'"
Write-Host "  - Run app:            dotnet run --project src/Host/$NewPrefix.WebApi"
Write-Host ""
