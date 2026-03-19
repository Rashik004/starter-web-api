<#
.SYNOPSIS
    Tests that each module can be independently removed from the solution.

.DESCRIPTION
    For each removable module:
    1. Comments out its using statements in Program.cs
    2. Comments out its extension method calls in Program.cs
    3. Removes its ProjectReference from Starter.WebApi.csproj
    4. Optionally renames dependent controllers to .bak
    5. Runs dotnet build
    6. Restores all files via git checkout

.PARAMETER Module
    Optional. Test a single module by name (e.g., "Starter.Cors") for debugging.

.EXAMPLE
    pwsh Scripts/test-module-removal.ps1
    pwsh Scripts/test-module-removal.ps1 -Module Starter.Cors
#>

param(
    [string]$Module = ""
)

$ErrorActionPreference = "Stop"

# Determine solution root (navigate up from script location to find slnx)
$ScriptDir = $PSScriptRoot
$SolutionRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\.." )).Path

$ProgramCs = Join-Path $SolutionRoot "src\Starter.WebApi\Program.cs"
$Csproj = Join-Path $SolutionRoot "src\Starter.WebApi\Starter.WebApi.csproj"
$ControllersDir = Join-Path $SolutionRoot "src\Starter.WebApi\Controllers"

if (-not (Test-Path $ProgramCs)) {
    Write-Error "Program.cs not found at $ProgramCs"
    exit 1
}

# Module definitions
# Each module has: Name, Usings (namespace strings to comment out), Calls (extension method patterns to comment out), Controllers (files to rename)
$Modules = @(
    # --- Tier 1: Pure infrastructure (no controller dependencies) ---
    @{ Name = "Starter.ExceptionHandling"; Usings = @("using Starter.ExceptionHandling;"); Calls = @("AddAppExceptionHandling", "UseAppExceptionHandling"); Controllers = @() },
    @{ Name = "Starter.Logging"; Usings = @("using Serilog;", "using Starter.Logging;"); Calls = @("AddAppLogging", "UseAppRequestLogging", "Log.Logger", "Log.Information", "Log.Fatal", "Log.CloseAndFlush", "LoggerConfiguration", "CreateBootstrapLogger", "Bootstrap Logger", "full Serilog pipeline", ".MinimumLevel", ".WriteTo.Console"); Controllers = @() },
    @{ Name = "Starter.Cors"; Usings = @("using Starter.Cors;"); Calls = @("AddAppCors"); Controllers = @() },
    @{ Name = "Starter.OpenApi"; Usings = @("using Starter.OpenApi;"); Calls = @("AddAppOpenApi", "UseAppOpenApi"); Controllers = @() },
    @{ Name = "Starter.RateLimiting"; Usings = @("using Starter.RateLimiting;"); Calls = @("AddAppRateLimiting", "UseAppRateLimiting"); Controllers = @() },
    @{ Name = "Starter.Compression"; Usings = @("using Starter.Compression;"); Calls = @(); Controllers = @() },
    @{ Name = "Starter.HealthChecks"; Usings = @("using Starter.HealthChecks;"); Calls = @("AddAppHealthChecks", "UseAppHealthChecks"); Controllers = @() },
    @{ Name = "Starter.Versioning"; Usings = @("using Starter.Versioning;"); Calls = @("AddAppVersioning"); Controllers = @("AuthController.cs", "TodoController.cs", "TodoV2Controller.cs", "CacheDemoController.cs") },
    @{ Name = "Starter.Validation"; Usings = @("using Starter.Validation;"); Calls = @("AddAppValidation"); Controllers = @() },
    @{ Name = "Starter.Auth.Google"; Usings = @("using Starter.Auth.Google;"); Calls = @("AddAppGoogle"); Controllers = @() },
    @{ Name = "Starter.Data"; Usings = @("using Starter.Data;"); Calls = @("AddAppData", "UseAppData"); Controllers = @() },
    @{ Name = "Starter.Data.Migrations.Sqlite"; Usings = @(); Calls = @(); Controllers = @() },
    @{ Name = "Starter.Data.Migrations.SqlServer"; Usings = @(); Calls = @(); Controllers = @() },
    @{ Name = "Starter.Data.Migrations.PostgreSql"; Usings = @(); Calls = @(); Controllers = @() },

    # --- Tier 2: Modules with controller dependencies ---
    @{ Name = "Starter.Auth.Shared"; Usings = @("using Starter.Auth.Shared;", "using Starter.Auth.Identity;", "using Starter.Auth.Jwt;", "using Starter.Auth.Google;"); Calls = @("AddAppAuthShared", "AddAppIdentity", "AddAppJwt", "AddAppGoogle"); Controllers = @("AuthController.cs") },
    @{ Name = "Starter.Auth.Identity"; Usings = @("using Starter.Auth.Identity;"); Calls = @("AddAppIdentity"); Controllers = @("AuthController.cs") },
    @{ Name = "Starter.Auth.Jwt"; Usings = @("using Starter.Auth.Jwt;"); Calls = @("AddAppJwt"); Controllers = @("AuthController.cs") },
    @{ Name = "Starter.Caching"; Usings = @("using Starter.Caching;"); Calls = @("AddAppCaching"); Controllers = @("CacheDemoController.cs") },
    @{ Name = "Starter.Responses"; Usings = @("using Starter.Responses;"); Calls = @("AddAppResponses"); Controllers = @("TodoController.cs") }
)

# Filter to single module if specified
if ($Module -ne "") {
    $filtered = $Modules | Where-Object { $_.Name -eq $Module }
    if ($filtered.Count -eq 0) {
        Write-Error "Module '$Module' not found. Available: $($Modules | ForEach-Object { $_.Name } | Join-String -Separator ', ')"
        exit 1
    }
    $Modules = @($filtered)
}

$passed = 0
$failed = 0
$failedModules = @()

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Module Removal Smoke Tests" -ForegroundColor Cyan
Write-Host "  Testing $($Modules.Count) module(s)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($mod in $Modules) {
    $moduleName = $mod.Name
    Write-Host "Testing removal of: $moduleName" -ForegroundColor Yellow -NoNewline

    try {
        # Read current file contents
        $programContent = Get-Content $ProgramCs -Raw
        $csprojContent = Get-Content $Csproj -Raw

        # 1. Comment out using statements in Program.cs
        $modifiedProgram = $programContent
        foreach ($usingStmt in $mod.Usings) {
            # Match the exact using line and comment it out (only if not already commented)
            $modifiedProgram = $modifiedProgram -replace "(?m)^(\s*)($([regex]::Escape($usingStmt)))", '$1// $2'
        }

        # 2. Comment out extension calls in Program.cs
        foreach ($call in $mod.Calls) {
            # Match lines containing the call pattern and comment them out (only if not already commented)
            $modifiedProgram = $modifiedProgram -replace "(?m)^(\s*)(?!//)(.*$([regex]::Escape($call)).*)$", '$1// $2'
        }

        # 3. Remove ProjectReference from csproj
        $modifiedCsproj = $csprojContent -replace "(?m)^\s*<ProjectReference Include="".+\\$([regex]::Escape($moduleName))\\[^""]+\.csproj""\s*/>\s*\r?\n?", ""

        # Write modified files
        Set-Content -Path $ProgramCs -Value $modifiedProgram -NoNewline
        Set-Content -Path $Csproj -Value $modifiedCsproj -NoNewline

        # 4. Rename controllers that depend on this module
        $renamedControllers = @()
        foreach ($controller in $mod.Controllers) {
            $controllerPath = Join-Path $ControllersDir $controller
            if (Test-Path $controllerPath) {
                $bakPath = "$controllerPath.bak"
                Rename-Item $controllerPath $bakPath
                $renamedControllers += @{ Original = $controllerPath; Backup = $bakPath }
            }
        }

        # 5. Run dotnet build
        $buildOutput = & dotnet build "$SolutionRoot\src\Starter.WebApi" 2>&1
        $buildExitCode = $LASTEXITCODE

        if ($buildExitCode -eq 0) {
            Write-Host " -> PASSED" -ForegroundColor Green
            $passed++
        } else {
            Write-Host " -> FAILED" -ForegroundColor Red
            $failed++
            $failedModules += $moduleName
            Write-Host "  Build output:" -ForegroundColor Red
            $buildOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
        }
    }
    catch {
        Write-Host " -> ERROR: $_" -ForegroundColor Red
        $failed++
        $failedModules += $moduleName
    }
    finally {
        # 6. Restore all files via git checkout (ultimate safety net)
        & git checkout -- $ProgramCs $Csproj 2>$null

        # Restore renamed controllers
        foreach ($rc in $renamedControllers) {
            if (Test-Path $rc.Backup) {
                if (Test-Path $rc.Original) { Remove-Item $rc.Original }
                Rename-Item $rc.Backup $rc.Original
            }
        }

        # Also restore entire Controllers directory just in case
        & git checkout -- "$ControllersDir/" 2>$null
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Total:  $($passed + $failed)" -ForegroundColor White
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failedModules.Count -gt 0) {
    Write-Host "`n  Failed modules:" -ForegroundColor Red
    foreach ($fm in $failedModules) {
        Write-Host "    - $fm" -ForegroundColor Red
    }
}

Write-Host ""

exit $(if ($failed -gt 0) { 1 } else { 0 })
