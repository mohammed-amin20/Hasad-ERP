<#
.SYNOPSIS
    Apply all Hasad ERP migrations to a production Supabase project.

.DESCRIPTION
    This script applies all migrations in order to a target Supabase project.
    Run from the repository root: .\supabase\production\apply_migrations.ps1

.PREREQUISITES
    - PowerShell 5.1+
    - Supabase project URL and service_role key (NOT anon key)
    - Migrations in ../migrations/ numbered 0001..0020

.PARAMETER SupabaseUrl
    Production Supabase project URL (e.g., https://xxxx.supabase.co)

.PARAMETER ServiceRoleKey
    Service role key from Settings → API (keep secret!)

.PARAMETER MigrationsPath
    Path to migrations folder (default: ../migrations)

.EXAMPLE
    .\apply_migrations.ps1 -SupabaseUrl "https://prod.supabase.co" -ServiceRoleKey "eyJ..."
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseUrl,

    [Parameter(Mandatory=$true)]
    [string]$ServiceRoleKey,

    [string]$MigrationsPath = "$PSScriptRoot\..\migrations"
)

# UTF-8 BOM for Arabic support
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8BOM'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8BOM'

function Invoke-SupabaseSql {
    param(
        [string]$Sql,
        [string]$Description
    )
    
    Write-Host "Applying: $Description" -ForegroundColor Cyan
    
    $headers = @{
        'Authorization' = "Bearer $ServiceRoleKey"
        'apikey' = $ServiceRoleKey
        'Content-Type' = 'application/json'
        'Prefer' = 'return=minimal'
    }
    
    $body = @{ query = $Sql } | ConvertTo-Json -Depth 10
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    
    try {
        $response = Invoke-RestMethod -Method Post `
            -Uri "$SupabaseUrl/rest/v1/rpc/exec_sql" `
            -Headers $headers `
            -Body $bodyBytes `
            -ContentType "application/json; charset=utf-8"
        
        Write-Host "  ✓ Success" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails) {
            Write-Host "  Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
        }
        return $false
    }
}

# Main
Write-Host "=== Hasad ERP Production Migration Runner ===" -ForegroundColor Magenta
Write-Host "Target: $SupabaseUrl"
Write-Host "Migrations: $MigrationsPath"
Write-Host ""

$migrationFiles = Get-ChildItem -Path $MigrationsPath -Filter "*.sql" | Sort-Object Name

if (-not $migrationFiles) {
    Write-Host "No migration files found in $MigrationsPath" -ForegroundColor Red
    exit 1
}

$failed = @()
$success = @()

foreach ($file in $migrationFiles) {
    $sql = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $desc = $file.Name
    
    if (Invoke-SupabaseSql -Sql $sql -Description $desc) {
        $success += $desc
    }
    else {
        $failed += $desc
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Magenta
Write-Host "Applied: $($success.Count)" -ForegroundColor Green
$success | ForEach-Object { Write-Host "  ✓ $_" -ForegroundColor Green }

if ($failed.Count -gt 0) {
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
    exit 1
}
else {
    Write-Host "All migrations applied successfully!" -ForegroundColor Green
}

# Verify key objects
Write-Host ""
Write-Host "Verifying key objects..." -ForegroundColor Cyan
$verifySql = @"
SELECT 
    (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public') as table_count,
    (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND prokind = 'f') as function_count,
    (SELECT count(*) FROM pg_cron.job) as cron_jobs;
"@

Invoke-SupabaseSql -Sql $verifySql -Description "Verification query"