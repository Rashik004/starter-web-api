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
    [switch]$SkipBuild,
    [switch]$IncludeBootstrapScripts
)

$ErrorActionPreference = 'Stop'

# Bootstrap scripts that should normally be left untouched so the template
# stays reusable. Skipped from Phase 2 content replacement when
# $script:skipBootstrap is true (default).
$bootstrapScriptPaths = @(
    'scripts\init-project.ps1'
    'scripts\rename-project.ps1'
    'scripts\rename-project.sh'
    'scripts\select-db-provider.ps1'
    'scripts\select-db-provider.sh'
)

# Resolve whether to skip them: explicit param wins; otherwise prompt with default Y.
if ($PSBoundParameters.ContainsKey('IncludeBootstrapScripts')) {
    $skipBootstrap = -not $IncludeBootstrapScripts.IsPresent
} else {
    Write-Host ""
    Write-Host "Skip bootstrap scripts during content replacement?" -ForegroundColor Cyan
    Write-Host "  (init-project, rename-project, select-db-provider .ps1/.sh)"
    $ans = Read-Host "Skip them? [Y/n]"
    $skipBootstrap = -not ($ans -match '^(n|no)$')
}

# ── Phase 0: Validate & Pre-flight ──────────────────────────────────────────

if ($NewPrefix -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$') {
    throw "Invalid prefix '$NewPrefix'. Must be a C# identifier or dotted namespace (e.g., 'Acme' or 'Acme.Server'). Hyphens are not allowed."
}

if ($NewPrefix -eq $OldPrefix) {
    throw "New prefix '$NewPrefix' is the same as old prefix '$OldPrefix'. Nothing to do."
}

$rootDir = Split-Path -Parent $PSScriptRoot
$slnxFile = Join-Path $rootDir "src\$OldPrefix.WebApi.slnx"

if (-not (Test-Path $slnxFile)) {
    throw "Solution file not found: $slnxFile. Are you running from the correct repo?"
}

$NewPrefixLower = $NewPrefix.ToLower()
$OldPrefixLower = $OldPrefix.ToLower()

# ── Phase 0.5: Detect target collisions before mutating anything ───────────

$collisions = New-Object System.Collections.Generic.List[string]

$newSlnx = Join-Path $rootDir "src\$NewPrefix.WebApi.slnx"
if (Test-Path $newSlnx) { $collisions.Add($newSlnx) }

$srcRoot = Join-Path $rootDir 'src'
$collisionExcludeDirs = @('.vs', 'bin', 'obj')
if (Test-Path $srcRoot) {
    Get-ChildItem -Path $srcRoot -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
        if ($_.Name -notlike "$NewPrefix*") { return $false }
        $rel = $_.FullName.Substring($rootDir.Length)
        foreach ($ex in $collisionExcludeDirs) {
            if ($rel -match "[\\/]$([regex]::Escape($ex))[\\/]") { return $false }
        }
        return $true
    } | ForEach-Object { [void]$collisions.Add($_.FullName) }
}

if ($collisions.Count -gt 0) {
    Write-Host ""
    Write-Host "Cannot rename: $($collisions.Count) target path(s) already exist (likely from a prior partial run):" -ForegroundColor Red
    $collisions | Select-Object -Unique | ForEach-Object {
        $rel = $_ -replace [regex]::Escape($rootDir), '.'
        Write-Host "  $rel" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Clean up first, then re-run. Suggested:" -ForegroundColor Yellow
    Write-Host "  git checkout HEAD -- src/" -ForegroundColor Yellow
    Write-Host "  git clean -fd src/" -ForegroundColor Yellow
    throw "Aborting before any changes. Resolve collisions and retry."
}

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

$includeExtensions = @('*.cs', '*.csproj', '*.slnx', '*.json', '*.ps1', '*.sh', '*.md', '*.yaml', '*.yml', 'Dockerfile')
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
        if (-not $excluded -and $skipBootstrap) {
            $rel = $relativePath.TrimStart('\', '/')
            foreach ($bs in $bootstrapScriptPaths) {
                if ($rel -ieq $bs -or $rel -ieq ($bs -replace '\\', '/')) {
                    $excluded = $true
                    break
                }
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

$srcPath = Join-Path $rootDir 'src'
if (Test-Path $srcPath) {
    Get-ChildItem -Path $srcPath -Filter '*.csproj' -Recurse -File | Where-Object {
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

$srcPath = Join-Path $rootDir 'src'
if (Test-Path $srcPath) {
    # Recurse all depths; sort deepest-first to avoid path invalidation
    Get-ChildItem -Path $srcPath -Directory -Recurse | Where-Object {
        $_.Name -like "$OldPrefix*"
    } | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        $newName = $_.Name -creplace [regex]::Escape($OldPrefix), $NewPrefix
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
$oldSlnxPath = Join-Path $rootDir "src\$oldSlnxName"
$newSlnxPath = Join-Path $rootDir "src\$newSlnxName"

if (Test-Path $oldSlnxPath) {
    Rename-Item -Path $oldSlnxPath -NewName $newSlnxName
    Write-Host "  src/$oldSlnxName -> src/$newSlnxName"
} else {
    Write-Host "  Solution file 'src/$oldSlnxName' not found (may have been renamed already)." -ForegroundColor Yellow
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
    $newSlnx = Join-Path $rootDir "src\$newSlnxName"
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
