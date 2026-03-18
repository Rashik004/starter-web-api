<#
.SYNOPSIS
    Updates the database for the specified provider to the latest (or specified) migration.
.EXAMPLE
    ./scripts/update-database.ps1 Sqlite
    ./scripts/update-database.ps1 Sqlite InitialCreate
#>
param(
    [Parameter(Mandatory)][ValidateSet('Sqlite', 'SqlServer', 'PostgreSql')][string]$Provider,
    [Parameter()][string]$MigrationName
)

$ErrorActionPreference = 'Stop'

$rootDir = Split-Path -Parent $PSScriptRoot

$projectMap = @{
    'Sqlite'     = 'src/Starter.Data.Migrations.Sqlite'
    'SqlServer'  = 'src/Starter.Data.Migrations.SqlServer'
    'PostgreSql' = 'src/Starter.Data.Migrations.PostgreSql'
}

$project = $projectMap[$Provider]

Write-Host "Updating database for provider '$Provider'..."

$env:Database__Provider = $Provider

$efArgs = @(
    '--startup-project', "$rootDir/src/Starter.WebApi",
    '--project', "$rootDir/$project"
)

if ($MigrationName) {
    dotnet ef database update $MigrationName @efArgs
} else {
    dotnet ef database update @efArgs
}

if ($LASTEXITCODE -ne 0) { throw "Database update failed with exit code $LASTEXITCODE" }

Write-Host "Database updated successfully for $Provider."
