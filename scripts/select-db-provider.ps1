<#
.SYNOPSIS
    Trims repo to a single EF Core database provider.
.DESCRIPTION
    Removes the two unused migration projects, trims .slnx + .csproj references,
    strips unused EF packages, rewrites DataExtensions.cs + DatabaseOptions.cs,
    and cleans appsettings. Stages changes (no commit).

    Detects the project prefix from the '*.WebApi.slnx' file (e.g., 'Acme' if
    the repo was already renamed via rename-project.ps1). Override with -Prefix.
.PARAMETER Provider
    Which provider to keep: Sqlite, SqlServer, or PostgreSql. Prompts if omitted.
.PARAMETER Prefix
    Project namespace prefix (e.g., 'Starter', 'Acme'). Auto-detected if omitted.
.PARAMETER DryRun
    Print planned changes without mutating anything.
.PARAMETER NoBackupBranch
    Skip the automatic pre-trim backup branch.
.PARAMETER Force
    Proceed even if git working tree is dirty.
.PARAMETER SkipBuild
    Skip the final dotnet build verification.
.EXAMPLE
    ./scripts/select-db-provider.ps1 -Provider Sqlite
.EXAMPLE
    ./scripts/select-db-provider.ps1 -Prefix Acme -Provider PostgreSql
.EXAMPLE
    ./scripts/select-db-provider.ps1 -DryRun
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Sqlite', 'SqlServer', 'PostgreSql')]
    [string]$Provider,
    [string]$Prefix,
    [switch]$DryRun,
    [switch]$NoBackupBranch,
    [switch]$Force,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step {
    param([string]$Tag, [string]$Message, [ConsoleColor]$Color = 'Cyan')
    Write-Host "[$Tag] " -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

function Confirm-Continue {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt [y/N]"
    return $ans -match '^(y|yes)$'
}

function Invoke-SaveXml {
    param([xml]$Xml, [string]$Path)
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.OmitXmlDeclaration = -not $Xml.FirstChild.NodeType.Equals([System.Xml.XmlNodeType]::XmlDeclaration)
    $settings.NewLineChars = "`r`n"
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $Xml.Save($writer) } finally { $writer.Dispose() }
}

function Resolve-Prefix {
    param([string]$RootDir, [string]$Explicit)

    if ($Explicit) {
        if ($Explicit -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$') {
            throw "Invalid prefix '$Explicit'. Must be a C# identifier or dotted namespace (e.g., 'Acme' or 'Acme.Server')."
        }
        $slnx = Join-Path $RootDir "src\$Explicit.WebApi.slnx"
        if (-not (Test-Path $slnx)) {
            throw "No 'src\$Explicit.WebApi.slnx' found. Check -Prefix value."
        }
        return $Explicit
    }

    $slnxSearch = Join-Path $RootDir 'src'
    $slnxFiles = @(Get-ChildItem -Path $slnxSearch -Filter '*.WebApi.slnx' -File -ErrorAction SilentlyContinue)
    if ($slnxFiles.Count -eq 1) {
        $detected = $slnxFiles[0].BaseName -replace '\.WebApi$', ''
        Write-Step 'DETECT' "Prefix '$detected' (from $($slnxFiles[0].Name))" 'Green'
        return $detected
    }

    if ($slnxFiles.Count -eq 0) {
        throw 'No *.WebApi.slnx found in repo root. Pass -Prefix explicitly.'
    }

    Write-Host "Multiple *.WebApi.slnx files found:" -ForegroundColor Yellow
    $slnxFiles | ForEach-Object { Write-Host "  $($_.Name)" }
    $explicit = Read-Host "Enter project prefix"
    return Resolve-Prefix -RootDir $RootDir -Explicit $explicit
}

# ---------------------------------------------------------------------------
# Templates (prefix-aware)
# ---------------------------------------------------------------------------

function Get-DataExtensionsTemplate {
    param([string]$Keep, [string]$Pfx)

    $migrationsAsm = "$Pfx.Data.Migrations.$Keep"

    $providerConfig = switch ($Keep) {
        'Sqlite' {
@"
            options.UseSqlite(
                builder.Configuration.GetConnectionString("Sqlite"),
                x =>
                {
                    x.MigrationsAssembly(MigrationsAssembly);
                    if (dbOptions.CommandTimeout > 0)
                        x.CommandTimeout(dbOptions.CommandTimeout);
                });
"@
        }
        'SqlServer' {
@"
            options.UseSqlServer(
                builder.Configuration.GetConnectionString("SqlServer"),
                x =>
                {
                    x.MigrationsAssembly(MigrationsAssembly);
                    x.EnableRetryOnFailure(
                        maxRetryCount: dbOptions.MaxRetryCount,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                    if (dbOptions.CommandTimeout > 0)
                        x.CommandTimeout(dbOptions.CommandTimeout);
                });
"@
        }
        'PostgreSql' {
@"
            options.UseNpgsql(
                builder.Configuration.GetConnectionString("PostgreSql"),
                x =>
                {
                    x.MigrationsAssembly(MigrationsAssembly);
                    x.EnableRetryOnFailure(
                        maxRetryCount: dbOptions.MaxRetryCount,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorCodesToAdd: null);
                    if (dbOptions.CommandTimeout > 0)
                        x.CommandTimeout(dbOptions.CommandTimeout);
                });
"@
        }
    }

    return @"
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using $Pfx.Data.Options;
using $Pfx.Data.Repositories;
using $Pfx.Data.Services;
using $Pfx.Shared.Contracts;

namespace $Pfx.Data;

public static class DataExtensions
{
    private const string MigrationsAssembly = "$migrationsAsm";

    /// <summary>
    /// Registers EF Core data services using the $Keep provider.
    /// </summary>
    public static WebApplicationBuilder AddAppData(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<DatabaseOptions>()
            .BindConfiguration(DatabaseOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        var dbOptions = builder.Configuration
            .GetSection(DatabaseOptions.SectionName)
            .Get<DatabaseOptions>()!;

        builder.Services.AddDbContext<AppDbContext>((sp, options) =>
        {
$providerConfig

            if (dbOptions.EnableSensitiveDataLogging)
                options.EnableSensitiveDataLogging();
        });

        builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
        builder.Services.AddScoped<ITodoService, TodoService>();

        return builder;
    }

    /// <summary>
    /// Applies pending EF Core migrations on startup when <c>Database:AutoMigrate</c> is true.
    /// </summary>
    public static WebApplication UseAppData(this WebApplication app)
    {
        var options = app.Configuration
            .GetSection(DatabaseOptions.SectionName)
            .Get<DatabaseOptions>();

        if (options?.AutoMigrate == true)
        {
            using var scope = app.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.Migrate();
        }

        return app;
    }
}
"@
}

function Get-DatabaseOptionsTemplate {
    param([string]$Keep, [string]$Pfx)

    $retryLine = if ($Keep -eq 'Sqlite') { '' } else { "    public int MaxRetryCount { get; set; } = 3;`r`n" }

    return @"
using System.ComponentModel.DataAnnotations;

namespace $Pfx.Data.Options;

internal sealed class DatabaseOptions
{
    public const string SectionName = "Database";

    public bool AutoMigrate { get; set; } = true;
    public int CommandTimeout { get; set; }
    public bool EnableSensitiveDataLogging { get; set; }
$retryLine}
"@
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

Push-Location $rootDir
try {
    $Prefix = Resolve-Prefix -RootDir $rootDir -Explicit $Prefix
    $prefixLower = $Prefix.ToLower()

    # Idempotency guard: if only one migration project remains, the repo is
    # already trimmed. Re-running would silently rewrite DataExtensions.cs from
    # template, blowing away any manual edits. Require -Force to proceed.
    $migrationsDir = Join-Path $rootDir 'src/Migrations'
    if (Test-Path $migrationsDir) {
        $existing = @(Get-ChildItem -Path $migrationsDir -Directory `
            -Filter "$Prefix.Data.Migrations.*" -ErrorAction SilentlyContinue)
        if ($existing.Count -le 1 -and -not $Force -and -not $DryRun) {
            $kept = if ($existing.Count -eq 1) {
                $existing[0].Name -replace "^$([regex]::Escape($Prefix))\.Data\.Migrations\.", ''
            } else { '(none)' }
            Write-Host "Repo appears already trimmed to $kept ($($existing.Count) migration project(s) found)." -ForegroundColor Yellow
            Write-Host "Pass -Force to re-run anyway, or -DryRun to see what would change." -ForegroundColor Yellow
            throw 'Aborted: idempotency guard.'
        }
    }

    if (-not $Force -and -not $DryRun) {
        $dirty = git status --porcelain
        if ($dirty) {
            Write-Host "Git working tree is dirty:" -ForegroundColor Yellow
            Write-Host $dirty
            if (-not (Confirm-Continue "Proceed anyway?")) {
                throw 'Aborted: commit or stash your changes first, or pass -Force.'
            }
        }
    }

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

    $all = @('Sqlite', 'SqlServer', 'PostgreSql')
    $drop = $all | Where-Object { $_ -ne $Provider }

    Write-Host ""
    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  Prefix: $Prefix"
    Write-Host "  Keep:   $Provider"
    Write-Host "  Drop:   $($drop -join ', ')"
    if ($DryRun) { Write-Host "  Mode:   DRY RUN (no changes)" -ForegroundColor Yellow }
    Write-Host ""

    if (-not $DryRun -and -not $Force) {
        if (-not (Confirm-Continue "Continue?")) { throw 'Aborted by user.' }
    }

    # -----------------------------------------------------------------------
    # 1. Backup branch
    # -----------------------------------------------------------------------

    if (-not $DryRun -and -not $NoBackupBranch) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $branch = "pre-db-trim-$ts"
        Write-Step 'GIT' "Creating backup branch '$branch'" 'Green'
        git checkout -b $branch | Out-Null
        git checkout - | Out-Null
        Write-Step 'GIT' "Backup branch created. Return with: git checkout $branch" 'Green'
    }

    # -----------------------------------------------------------------------
    # 2. Delete migration projects
    # -----------------------------------------------------------------------

    foreach ($d in $drop) {
        $path = Join-Path $rootDir "src/Migrations/$Prefix.Data.Migrations.$d"
        if (Test-Path $path) {
            Write-Step 'DELETE' $path 'Red'
            if (-not $DryRun) { Remove-Item -Recurse -Force $path }
        } else {
            Write-Step 'SKIP' "$path (missing)" 'DarkGray'
        }
    }

    # -----------------------------------------------------------------------
    # 3. Edit .slnx
    # -----------------------------------------------------------------------

    $slnxPath = Join-Path $rootDir "src/$Prefix.WebApi.slnx"
    Write-Step 'EDIT' $slnxPath
    if (-not $DryRun) {
        [xml]$slnx = Get-Content $slnxPath -Raw
        foreach ($d in $drop) {
            $pattern = "Migrations/$Prefix.Data.Migrations.$d/$Prefix.Data.Migrations.$d.csproj"
            $nodes = @($slnx.SelectNodes("//Project[@Path='$pattern']"))
            foreach ($n in $nodes) { [void]$n.ParentNode.RemoveChild($n) }
        }
        Invoke-SaveXml -Xml $slnx -Path $slnxPath
    }

    # -----------------------------------------------------------------------
    # 4. Edit host .csproj
    # -----------------------------------------------------------------------

    $hostCsprojPath = Join-Path $rootDir "src/Host/$Prefix.WebApi/$Prefix.WebApi.csproj"
    Write-Step 'EDIT' $hostCsprojPath
    if (-not $DryRun) {
        [xml]$hostCsproj = Get-Content $hostCsprojPath -Raw
        foreach ($d in $drop) {
            $rel = "..\..\Migrations\$Prefix.Data.Migrations.$d\$Prefix.Data.Migrations.$d.csproj"
            $nodes = @($hostCsproj.SelectNodes("//ProjectReference[@Include='$rel']"))
            foreach ($n in $nodes) { [void]$n.ParentNode.RemoveChild($n) }
        }
        Invoke-SaveXml -Xml $hostCsproj -Path $hostCsprojPath
    }

    # -----------------------------------------------------------------------
    # 5. Edit data .csproj: drop InternalsVisibleTo + unused EF packages
    # -----------------------------------------------------------------------

    $dataCsprojPath = Join-Path $rootDir "src/Modules/$Prefix.Data/$Prefix.Data.csproj"
    Write-Step 'EDIT' $dataCsprojPath
    $providerPackage = @{
        'Sqlite'     = 'Microsoft.EntityFrameworkCore.Sqlite'
        'SqlServer'  = 'Microsoft.EntityFrameworkCore.SqlServer'
        'PostgreSql' = 'Npgsql.EntityFrameworkCore.PostgreSQL'
    }
    if (-not $DryRun) {
        [xml]$dataCsproj = Get-Content $dataCsprojPath -Raw

        foreach ($d in $drop) {
            $asm = "$Prefix.Data.Migrations.$d"
            $nodes = @($dataCsproj.SelectNodes("//InternalsVisibleTo[@Include='$asm']"))
            foreach ($n in $nodes) { [void]$n.ParentNode.RemoveChild($n) }

            $pkg = $providerPackage[$d]
            $pkgNodes = @($dataCsproj.SelectNodes("//PackageReference[@Include='$pkg']"))
            foreach ($n in $pkgNodes) { [void]$n.ParentNode.RemoveChild($n) }
        }
        Invoke-SaveXml -Xml $dataCsproj -Path $dataCsprojPath
    }

    # -----------------------------------------------------------------------
    # 6. Rewrite DataExtensions.cs
    # -----------------------------------------------------------------------

    $dataExtPath = Join-Path $rootDir "src/Modules/$Prefix.Data/DataExtensions.cs"
    Write-Step 'EDIT' $dataExtPath
    if (-not $DryRun) {
        Set-Content -Path $dataExtPath -Value (Get-DataExtensionsTemplate -Keep $Provider -Pfx $Prefix) -Encoding UTF8
    }

    # -----------------------------------------------------------------------
    # 7. Rewrite DatabaseOptions.cs
    # -----------------------------------------------------------------------

    $dbOptsPath = Join-Path $rootDir "src/Modules/$Prefix.Data/Options/DatabaseOptions.cs"
    Write-Step 'EDIT' $dbOptsPath
    if (-not $DryRun) {
        Set-Content -Path $dbOptsPath -Value (Get-DatabaseOptionsTemplate -Keep $Provider -Pfx $Prefix) -Encoding UTF8
    }

    # -----------------------------------------------------------------------
    # 8. Edit appsettings files
    # -----------------------------------------------------------------------

    # Surgical line removal (preserves comments + formatting).
    # Each needle matches exactly the assignment line for a JSON key. Comments
    # mentioning these keys in unquoted prose are not affected because the
    # needle includes the quoted-key + colon prefix.
    $appsettingsFiles = @(
        "src/Host/$Prefix.WebApi/appsettings.json"
        "src/Host/$Prefix.WebApi/appsettings.Development.json"
    )
    foreach ($rel in $appsettingsFiles) {
        $path = Join-Path $rootDir $rel
        if (-not (Test-Path $path)) { continue }
        Write-Step 'EDIT' $path
        if ($DryRun) { continue }

        $needles = New-Object System.Collections.Generic.List[string]
        # Remove Database:Provider line.
        $needles.Add('"Provider":')
        # Remove MaxRetryCount when keeping SQLite (Sqlite ignores it).
        if ($Provider -eq 'Sqlite') { $needles.Add('"MaxRetryCount":') }
        # Remove dropped providers from ConnectionStrings.
        foreach ($d in $drop) { $needles.Add("`"$d`":") }

        $lines = [System.IO.File]::ReadAllLines($path)
        $kept = $lines | Where-Object {
            $line = $_
            $remove = $false
            foreach ($n in $needles) { if ($line -like "*$n*") { $remove = $true; break } }
            -not $remove
        }
        # Tidy: a line ending in `,` immediately followed by `}` or `]` would
        # become a JSON syntax error after removing the next key. Strip the
        # trailing comma on the last property line of any object/array.
        $tidied = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $kept.Count; $i++) {
            $cur = $kept[$i]
            $nxt = if ($i + 1 -lt $kept.Count) { $kept[$i + 1].TrimStart() } else { '' }
            if ($cur -match '^(.*?)(,)(\s*)$' -and ($nxt.StartsWith('}') -or $nxt.StartsWith(']'))) {
                $cur = $Matches[1] + $Matches[3]
            }
            $tidied.Add($cur)
        }
        [System.IO.File]::WriteAllLines($path, $tidied, [System.Text.UTF8Encoding]::new($false))
    }

    # -----------------------------------------------------------------------
    # 9. Delete SQLite DB file if switching away from Sqlite
    # -----------------------------------------------------------------------

    if ($Provider -ne 'Sqlite') {
        $hostDir = Join-Path $rootDir "src/Host/$Prefix.WebApi"
        if (Test-Path $hostDir) {
            $dbFiles = Get-ChildItem -Path $hostDir -Filter "$prefixLower.db*" -ErrorAction SilentlyContinue
            foreach ($f in $dbFiles) {
                Write-Step 'DELETE' $f.FullName 'Red'
                if (-not $DryRun) { Remove-Item -Force $f.FullName }
            }
        }
    }

    # -----------------------------------------------------------------------
    # 9b. Trim Docker compose files
    # -----------------------------------------------------------------------

    $composeDir = Join-Path $rootDir 'docker'
    $providerToFile = @{
        'Sqlite'     = 'compose.sqlite.yaml'
        'PostgreSql' = 'compose.postgres.yaml'
        'SqlServer'  = 'compose.sqlserver.yaml'
    }
    $keepFilename = $providerToFile[$Provider]
    $keepPath     = Join-Path $composeDir $keepFilename
    $finalPath    = Join-Path $composeDir 'compose.yaml'

    function Get-RepoRelativePath {
        param([string]$Path)
        $rootFull = [System.IO.Path]::GetFullPath($rootDir)
        $pathFull = [System.IO.Path]::GetFullPath($Path)
        if ($pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ($pathFull.Substring($rootFull.Length).TrimStart('\', '/')) -replace '\\', '/'
        }
        return ($Path -replace '\\', '/')
    }

    function Test-GitTracked {
        param([string]$Path)
        git -C $rootDir ls-files --error-unmatch -- (Get-RepoRelativePath $Path) 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }

    if (-not (Test-Path $composeDir)) {
        Write-Step 'SKIP' "docker/ directory absent — skipping compose trim" 'DarkGray'
    } elseif (-not (Test-Path $keepPath)) {
        # Check idempotency: if compose.yaml exists and no shards remain, already trimmed
        $shards = @(Get-ChildItem -Path $composeDir -Filter 'compose.*.yaml' -File -ErrorAction SilentlyContinue)
        if ((Test-Path $finalPath) -and $shards.Count -eq 0) {
            # Verify the existing compose.yaml's Database__Provider matches the requested
            # provider. Otherwise we'd silently leave compose pointing at the OLD provider
            # while the .NET code is switched to the NEW one — broken stack with no error.
            $composeContent = Get-Content -Path $finalPath -Raw -ErrorAction SilentlyContinue
            $existingProvider = $null
            if ($composeContent -match 'Database__Provider:\s*([A-Za-z]+)') {
                $existingProvider = $Matches[1]
            }
            if ($existingProvider -and $existingProvider -ne $Provider) {
                throw "Provider mismatch: docker/compose.yaml is already trimmed to '$existingProvider' but you requested '$Provider'. The .NET code WAS switched, but compose.yaml would silently launch the wrong DB. To recover: 'git restore docker/' to bring back the shards, then re-run."
            }
            Write-Step 'SKIP' "compose files already trimmed — skipping" 'DarkGray'
        } else {
            Write-Step 'WARN' "kept compose file '$keepFilename' missing — leaving compose dir untouched" 'Yellow'
        }
    } else {
        # Delete unused compose shards
        $shards = @(Get-ChildItem -Path $composeDir -Filter 'compose.*.yaml' -File -ErrorAction SilentlyContinue)
        foreach ($shard in $shards) {
            if ($shard.FullName -ne $keepPath) {
                Write-Step 'DELETE' $shard.FullName 'Red'
                if (-not $DryRun) {
                    if (Test-GitTracked -Path $shard.FullName) {
                        git -C $rootDir rm -- (Get-RepoRelativePath $shard.FullName)
                    } else {
                        Remove-Item -Force $shard.FullName
                    }
                }
            }
        }
        # Rename kept shard → compose.yaml (skip if already at final path)
        if ($keepPath -ne $finalPath) {
            Write-Step 'EDIT' "$keepPath -> $finalPath"
            if (-not $DryRun) {
                if (Test-GitTracked -Path $keepPath) {
                    git -C $rootDir mv -- (Get-RepoRelativePath $keepPath) (Get-RepoRelativePath $finalPath)
                } else {
                    Move-Item -Force $keepPath $finalPath
                }
            }
        }
    }

    # -----------------------------------------------------------------------
    # 10. Warn about architecture tests
    # -----------------------------------------------------------------------

    $archScripts = @(
        "src/tests/$Prefix.WebApi.Tests.Architecture/Scripts/test-module-removal.ps1"
        "src/tests/$Prefix.WebApi.Tests.Architecture/Scripts/test-module-removal.sh"
    )
    foreach ($rel in $archScripts) {
        $path = Join-Path $rootDir $rel
        if (Test-Path $path) {
            Write-Step 'WARN' "Manual edit needed: $rel references dropped migration project(s)" 'Yellow'
        }
    }

    # -----------------------------------------------------------------------
    # 11. Build verify
    # -----------------------------------------------------------------------

    if (-not $DryRun -and -not $SkipBuild) {
        Write-Host ""
        $slnxBuildPath = Join-Path $rootDir "src/$Prefix.WebApi.slnx"
        Write-Step 'BUILD' 'dotnet restore + build' 'Green'
        dotnet restore $slnxBuildPath | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'dotnet restore failed.' }
        dotnet build $slnxBuildPath --nologo -v quiet
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "Build failed. Rollback with:" -ForegroundColor Red
            Write-Host "  git reset --hard HEAD && git clean -fd" -ForegroundColor Red
            throw 'Build failure after trim.'
        }
    }

    # -----------------------------------------------------------------------
    # 12. Stage changes
    # -----------------------------------------------------------------------

    if (-not $DryRun) {
        Write-Step 'GIT' 'Staging changes (no commit)' 'Green'
        git add -A
    }

    Write-Host ""
    Write-Host "Done. Prefix: $Prefix. Kept: $Provider. Dropped: $($drop -join ', ')." -ForegroundColor Green
    Write-Host "Next:"
    Write-Host "  - Review staged diff: git diff --cached"
    Write-Host "  - Commit when ready:  git commit -m 'chore: trim DB providers to $Provider'"
    Write-Host "  - Run app:            dotnet run --project src/Host/$Prefix.WebApi"
}
finally {
    Pop-Location
}
