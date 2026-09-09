<#
.SYNOPSIS
    Run pgTAP regression tests against a Supabase project.

.DESCRIPTION
    Executes the pgTAP test suite (run_pgtap_tests.sql) against a target Supabase database.
    Requires: PostgreSQL client (psql) installed and in PATH.

.PARAMETER SupabaseHost
    Database host (e.g., db.xxxxx.supabase.co)

.PARAMETER Database
    Database name (default: postgres)

.PARAMETER Username
    Database user (default: postgres)

.PARAMETER Password
    Database password

.PARAMETER TestsPath
    Path to pgTAP test SQL file

.EXAMPLE
    .\run_pgtap.ps1 -SupabaseHost "db.xxxxx.supabase.co" -Password "xxx"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseHost,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [string]$Database = "postgres",
    [string]$Username = "postgres",
    [string]$TestsPath = "$PSScriptRoot\run_pgtap_tests.sql"
)

if (-not (Test-Path $TestsPath)) {
    Write-Host "Test file not found: $TestsPath" -ForegroundColor Red
    exit 1
}

Write-Host "=== Hasad ERP pgTAP Test Runner ===" -ForegroundColor Magenta
Write-Host "Host: $SupabaseHost"
Write-Host "Database: $Database"
Write-Host "Test file: $TestsPath"
Write-Host ""

# Check psql exists
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host "psql not found in PATH. Install PostgreSQL client tools." -ForegroundColor Red
    exit 1
}

Write-Host "Using psql: $($psql.Source)" -ForegroundColor Cyan

# Run tests
$env:PGPASSWORD = $Password
$cmd = "psql -h $SupabaseHost -U $Username -d $Database -f `"$TestsPath`" -v ON_ERROR_STOP=0"

Write-Host "Running: $cmd" -ForegroundColor Cyan
Write-Host ""

try {
    $result = & cmd /c $cmd 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Host $result
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "=== pgTAP Tests PASSED ===" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "=== pgTAP Tests FAILED (exit code: $exitCode) ===" -ForegroundColor Red
    }
}
catch {
    Write-Host "Execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

exit $exitCode