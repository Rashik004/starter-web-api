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
    (init-project, rename-project, select-db-provider .ps1/.sh). Default: skip
    them silently so the template stays reusable. Power users opt in.
.PARAMETER NoJwtSecret
    Skip auto-generation of the Jwt:SecretKey user-secret. Default: generate a
    48-byte base64 key and store it via 'dotnet user-secrets'. Pass this for
    CI/automated bootstraps where the secret is supplied separately.
.PARAMETER NoEnvFile
    Skip generation of the .env file at the repo root. Default: write .env
    with JWT_SECRET_KEY and provider-specific DB credentials for Docker Compose.
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
    [switch]$IncludeBootstrapScripts,
    [switch]$NoJwtSecret,
    [switch]$NoEnvFile
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
    Write-Host "  1) Sqlite     (default, zero-config, file-based)"
    Write-Host "  2) SqlServer"
    Write-Host "  3) PostgreSql"
    $choice = Read-Host "Choice [1-3] (default: 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
    $Provider = switch ($choice) {
        '1' { 'Sqlite' }
        '2' { 'SqlServer' }
        '3' { 'PostgreSql' }
        default { throw "Invalid choice: $choice" }
    }
}

# ── Phase 2b: Resolve bootstrap-script handling ────────────────────────────
# Default: skip the bootstrap scripts so the template stays reusable.
# Power users opt in with -IncludeBootstrapScripts.

$skipBootstrap = -not $IncludeBootstrapScripts.IsPresent

# ── Phase 3: Combined plan summary ─────────────────────────────────────────

Write-Host ""
Write-Host "=== init-project plan ===" -ForegroundColor Cyan
Write-Host "  Rename:        $OldPrefix -> $NewPrefix"
Write-Host "  Provider:      keep $Provider (drop the others)"
Write-Host "  SkipBuild:     $SkipBuild"
Write-Host "  Backup br.:    $(-not $NoBackupBranch)"
Write-Host "  Skip bootstr.: $skipBootstrap"
Write-Host "  JWT secret:    $(if ($NoJwtSecret) { 'skipped' } else { 'auto-generate' })"
Write-Host "  .env file:     $(if ($NoEnvFile) { 'skipped' } else { 'write at repo root' })"
Write-Host ""
Write-Host "  Step 1/4: scripts/rename-project.ps1"
Write-Host "  Step 2/4: scripts/select-db-provider.ps1 (with -Force, since rename leaves tree dirty)"
if (-not $NoJwtSecret) {
    Write-Host "  Step 3/4: dotnet user-secrets set Jwt:SecretKey (auto-generated)"
}
if (-not $NoEnvFile) {
    Write-Host "  Step 4/4: Write .env file for Docker (skip with -NoEnvFile)"
}
Write-Host ""

if (-not $Force) {
    if (-not (Confirm-Continue "Continue?")) { throw 'Aborted by user.' }
}

# ── Phase 4: Rename ────────────────────────────────────────────────────────

Write-Host ""
Write-Host ">>> [1/4] Running rename-project.ps1..." -ForegroundColor Green
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
Write-Host ">>> [2/4] Running select-db-provider.ps1..." -ForegroundColor Green
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

# ── Phase 6: JWT signing key ───────────────────────────────────────────────

if (-not $NoJwtSecret) {
    Write-Host ""
    Write-Host ">>> [3/4] Generating JWT signing key..." -ForegroundColor Green
    Write-Host ""

    $hostCsproj = Join-Path $rootDir "src/Host/$NewPrefix.WebApi/$NewPrefix.WebApi.csproj"
    if (-not (Test-Path $hostCsproj)) {
        Write-Host "WARNING: host csproj not found at $hostCsproj -- skipping JWT secret." -ForegroundColor Yellow
    } else {
        # Generate a 48-byte (384-bit) base64-encoded secret.
        $secretBytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
        $jwtSecret = [Convert]::ToBase64String($secretBytes)

        # Idempotent: 'init' adds a UserSecretsId only if absent.
        dotnet user-secrets init --project $hostCsproj | Out-Null
        dotnet user-secrets set 'Jwt:SecretKey' $jwtSecret --project $hostCsproj | Out-Null

        Write-Host "JWT signing key written to user-secrets store for $NewPrefix.WebApi."
        Write-Host "  (Secret value is not echoed. Retrieve with: dotnet user-secrets list --project src/Host/$NewPrefix.WebApi)"
    }
}

# ── Phase 7: Write .env file (Docker) ─────────────────────────────────────

$envWritten = $false
if (-not $NoEnvFile) {
    Write-Host ""
    Write-Host ">>> [4/4] Writing .env file..." -ForegroundColor Green
    Write-Host ""

    $envPath = Join-Path $rootDir '.env'
    if (Test-Path $envPath) {
        Write-Host "WARNING: Skipping .env: file already exists at $envPath" -ForegroundColor Yellow
    } else {
        # Generate a fresh JWT secret for .env; user-secrets (Phase 6) and Docker are
        # separate environments, so using independent keys is intentional.
        $envJwtBytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
        $envJwtSecret = [Convert]::ToBase64String($envJwtBytes)

        $lines = @(
            "JWT_SECRET_KEY=$envJwtSecret",
            "CORS_ORIGIN=http://localhost:8080"
        )

        switch ($Provider) {
            'PostgreSql' {
                $pgPwd = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
                $lines += "POSTGRES_USER=starter"
                $lines += "POSTGRES_PASSWORD=$pgPwd"
                $lines += "POSTGRES_DB=starterdb"
            }
            'SqlServer' {
                # Prepend "Aa1!" to guarantee SQL Server complexity rules (mixed case, digit, symbol).
                $rawPwd = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
                $saPwd = "Aa1!$rawPwd"
                $lines += "MSSQL_SA_PASSWORD=$saPwd"
            }
            # Sqlite: no extra keys needed.
        }

        [System.IO.File]::WriteAllText($envPath, ($lines -join "`n") + "`n")

        Write-Host "Wrote .env (gitignored). Run: docker compose up"
        $envWritten = $true
    }
}

# ── Phase 8: Done ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=== init-project complete ===" -ForegroundColor Green
Write-Host "  Renamed:  $OldPrefix -> $NewPrefix"
Write-Host "  Provider: $Provider"
if (-not $NoJwtSecret) {
    Write-Host "  JWT key:  set in user-secrets"
}
if ($envWritten) {
    Write-Host "  .env:     written at repo root"
}
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  - Review staged diff: git diff --cached"
Write-Host "  - Commit when ready:  git commit -m 'chore: bootstrap $NewPrefix with $Provider provider'"
Write-Host "  - Run app:            dotnet run --project src/Host/$NewPrefix.WebApi"
Write-Host ""
