<#
.SYNOPSIS
    Renames the project prefix throughout the entire solution (namespaces, folders, files, config).
.DESCRIPTION
    Replaces all occurrences of the old prefix (default "Starter") with a new prefix in file contents,
    file names, and directory names. Designed for bootstrapping a new project from this template.
.EXAMPLE
    ./scripts/rename-project.ps1 -NewPrefix Acme
.EXAMPLE
    ./scripts/rename-project.ps1 -NewPrefix Acme -SkipBuild
.EXAMPLE
    ./scripts/rename-project.ps1 -NewPrefix Contoso -OldPrefix Acme
#>
param(
    [Parameter(Mandatory)][string]$NewPrefix,
    [string]$OldPrefix = 'Starter',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

# ── Phase 0: Validate & Pre-flight ──────────────────────────────────────────

if ($NewPrefix -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    throw "Invalid prefix '$NewPrefix'. Must be a valid C# identifier (start with letter/underscore, alphanumeric)."
}

if ($NewPrefix -eq $OldPrefix) {
    throw "New prefix '$NewPrefix' is the same as old prefix '$OldPrefix'. Nothing to do."
}

$rootDir = Split-Path -Parent $PSScriptRoot
$slnxFile = Join-Path $rootDir "$OldPrefix.WebApi.slnx"

if (-not (Test-Path $slnxFile)) {
    throw "Solution file not found: $slnxFile. Are you running from the correct repo?"
}

$NewPrefixLower = $NewPrefix.ToLower()
$OldPrefixLower = $OldPrefix.ToLower()

Write-Host ""
Write-Host "=== Project Rename: '$OldPrefix' -> '$NewPrefix' ===" -ForegroundColor Cyan
Write-Host "  Solution root: $rootDir"
Write-Host ""

# Warn if git working tree is dirty
$gitStatus = git -C $rootDir status --porcelain 2>$null
if ($gitStatus) {
    Write-Host "WARNING: Git working tree has uncommitted changes." -ForegroundColor Yellow
    Write-Host "  Consider committing or stashing before renaming." -ForegroundColor Yellow
    Write-Host ""
}

# ── Phase 1: Clean build artifacts ──────────────────────────────────────────

Write-Host "[Phase 1] Cleaning build artifacts..." -ForegroundColor Cyan

$dirsToClean = @('bin', 'obj')
foreach ($parent in @('src', 'tests')) {
    $parentPath = Join-Path $rootDir $parent
    if (Test-Path $parentPath) {
        Get-ChildItem -Path $parentPath -Directory -Recurse -Include $dirsToClean | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force
            Write-Host "  Deleted: $($_.FullName -replace [regex]::Escape($rootDir), '.')"
        }
    }
}

$vsDir = Join-Path $rootDir '.vs'
if (Test-Path $vsDir) {
    Remove-Item $vsDir -Recurse -Force
    Write-Host "  Deleted: .vs/"
}

Write-Host ""

# ── Phase 2: Replace file contents ─────────────────────────────────────────

Write-Host "[Phase 2] Replacing file contents..." -ForegroundColor Cyan

$includeExtensions = @('*.cs', '*.csproj', '*.slnx', '*.json', '*.ps1', '*.sh', '*.md')
$excludeDirs = @('.git', 'bin', 'obj', '.vs', '.planning', '.claude')

$filesModified = 0

foreach ($ext in $includeExtensions) {
    $files = Get-ChildItem -Path $rootDir -Filter $ext -Recurse -File | Where-Object {
        # Check relative path (from root) to avoid false matches in parent directories
        $relativePath = $_.FullName.Substring($rootDir.Length)
        $excluded = $false
        foreach ($dir in $excludeDirs) {
            if ($relativePath -match "[\\/]$([regex]::Escape($dir))[\\/]") {
                $excluded = $true
                break
            }
        }
        -not $excluded
    }

    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw
        if ($null -eq $content) { continue }

        $original = $content

        # Pass 1: PascalCase replacement (e.g., Starter -> Acme)
        $content = $content -creplace [regex]::Escape($OldPrefix), $NewPrefix

        # Pass 2: Lowercase replacement (e.g., starter -> acme)
        if ($OldPrefixLower -cne $OldPrefix) {
            $content = $content -creplace [regex]::Escape($OldPrefixLower), $NewPrefixLower
        }

        if ($content -cne $original) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            $relativePath = $file.FullName -replace [regex]::Escape($rootDir), '.'
            Write-Host "  Updated: $relativePath"
            $filesModified++
        }
    }
}

Write-Host "  $filesModified file(s) modified."
Write-Host ""

# ── Phase 3: Rename .csproj files ──────────────────────────────────────────

Write-Host "[Phase 3] Renaming .csproj files..." -ForegroundColor Cyan

$csprojsRenamed = 0

foreach ($parent in @('src', 'tests')) {
    $parentPath = Join-Path $rootDir $parent
    if (-not (Test-Path $parentPath)) { continue }

    Get-ChildItem -Path $parentPath -Filter '*.csproj' -Recurse -File | Where-Object {
        $_.Name -like "$OldPrefix*"
    } | ForEach-Object {
        $newName = $_.Name -creplace [regex]::Escape($OldPrefix), $NewPrefix
        Rename-Item -Path $_.FullName -NewName $newName
        Write-Host "  $($_.Name) -> $newName"
        $csprojsRenamed++
    }
}

Write-Host "  $csprojsRenamed .csproj file(s) renamed."
Write-Host ""

# ── Phase 4: Rename project directories ────────────────────────────────────

Write-Host "[Phase 4] Renaming project directories..." -ForegroundColor Cyan

$dirsRenamed = 0

foreach ($parent in @('src', 'tests')) {
    $parentPath = Join-Path $rootDir $parent
    if (-not (Test-Path $parentPath)) { continue }

    # Get immediate child directories starting with old prefix
    # Process in reverse order to handle nested paths correctly
    Get-ChildItem -Path $parentPath -Directory | Where-Object {
        $_.Name -like "$OldPrefix*"
    } | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        $newName = $_.Name -creplace [regex]::Escape($OldPrefix), $NewPrefix
        $newPath = Join-Path $_.Parent.FullName $newName
        Rename-Item -Path $_.FullName -NewName $newName
        Write-Host "  $($_.Name) -> $newName"
        $dirsRenamed++
    }
}

Write-Host "  $dirsRenamed director(ies) renamed."
Write-Host ""

# ── Phase 5: Rename .slnx file ────────────────────────────────────────────

Write-Host "[Phase 5] Renaming solution file..." -ForegroundColor Cyan

$oldSlnxName = "$OldPrefix.WebApi.slnx"
$newSlnxName = "$NewPrefix.WebApi.slnx"
$oldSlnxPath = Join-Path $rootDir $oldSlnxName
$newSlnxPath = Join-Path $rootDir $newSlnxName

if (Test-Path $oldSlnxPath) {
    Rename-Item -Path $oldSlnxPath -NewName $newSlnxName
    Write-Host "  $oldSlnxName -> $newSlnxName"
} else {
    Write-Host "  Solution file '$oldSlnxName' not found (may have been renamed already)." -ForegroundColor Yellow
}

Write-Host ""

# ── Phase 6: Verification ─────────────────────────────────────────────────

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Files modified:      $filesModified"
Write-Host "  .csproj renamed:     $csprojsRenamed"
Write-Host "  Directories renamed: $dirsRenamed"
Write-Host "  Solution file:       $oldSlnxName -> $newSlnxName"
Write-Host ""

if (-not $SkipBuild) {
    Write-Host "[Phase 6] Running verification build..." -ForegroundColor Cyan
    $newSlnx = Join-Path $rootDir $newSlnxName
    dotnet build $newSlnx
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "BUILD FAILED. Review the errors above." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "Build succeeded!" -ForegroundColor Green
} else {
    Write-Host "Build skipped (-SkipBuild)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Rename complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Post-rename checklist:" -ForegroundColor Yellow
Write-Host "  1. Delete old SQLite database if it exists (e.g., $($OldPrefixLower).db)"
Write-Host "  2. Update user secrets ID if using 'dotnet user-secrets'"
Write-Host "  3. Close and reopen your IDE to refresh caches"
Write-Host ""
