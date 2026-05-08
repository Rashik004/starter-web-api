<#
.SYNOPSIS
    Adds an EF Core migration for the specified database provider.
.EXAMPLE
    ./scripts/add-migration.ps1 Sqlite InitialCreate
#>
param(
    [Parameter(Mandatory)][ValidateSet('Sqlite', 'SqlServer', 'PostgreSql')][string]$Provider,
    [Parameter(Mandatory)][string]$MigrationName
)

$ErrorActionPreference = 'Stop'

$rootDir = Split-Path -Parent $PSScriptRoot

$projectMap = @{
    'Sqlite'     = 'src/Migrations/Starter.Data.Migrations.Sqlite'
    'SqlServer'  = 'src/Migrations/Starter.Data.Migrations.SqlServer'
    'PostgreSql' = 'src/Migrations/Starter.Data.Migrations.PostgreSql'
}

$project = $projectMap[$Provider]

Write-Host "Adding migration '$MigrationName' for provider '$Provider'..."
Write-Host "  Migration project: $project"
Write-Host "  Startup project:   src/Host/Starter.WebApi"

$env:Database__Provider = $Provider

dotnet ef migrations add $MigrationName `
    --startup-project "$rootDir/src/Host/Starter.WebApi" `
    --project "$rootDir/$project"

if ($LASTEXITCODE -ne 0) { throw "Migration failed with exit code $LASTEXITCODE" }

Write-Host "Migration '$MigrationName' added successfully for $Provider."
