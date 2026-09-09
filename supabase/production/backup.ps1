<#
.SYNOPSIS
    Backup Hasad ERP production database (full or tenant-scoped).

.DESCRIPTION
    Uses pg_dump to create SQL backups. Requires PostgreSQL client tools installed.

.PARAMETER SupabaseHost
    Database host from Supabase Settings → Database (e.g., db.xxxxx.supabase.co)

.PARAMETER Database
    Database name (usually 'postgres')

.PARAMETER Username
    Database user (usually 'postgres')

.PARAMETER Password
    Database password (from Supabase Settings → Database)

.PARAMETER TenantId
    Optional: specific tenant UUID for tenant-scoped backup

.PARAMETER OutputDir
    Directory to save backup files (default: ./backups)

.EXAMPLE
    # Full backup
    .\backup.ps1 -SupabaseHost "db.xxxxx.supabase.co" -Password "xxx"

    # Tenant-scoped backup
    .\backup.ps1 -SupabaseHost "db.xxxxx.supabase.co" -Password "xxx" -TenantId "uuid-here"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SupabaseHost,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [string]$Database = "postgres",
    [string]$Username = "postgres",
    [string]$TenantId,
    [string]$OutputDir = "$PSScriptRoot\backups"
)

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tables = @(
    'tenants', 'users', 'customers', 'suppliers', 'products',
    'invoices', 'invoice_items', 'payments', 'journal_entries', 'journal_entry_lines',
    'commission_dues', 'employees', 'salaries', 'employee_movements', 'stock_moves',
    'expenses', 'accounts', 'reminder_log', 'tenant_settings', 'invoice_counters',
    'processed_requests'
)

if ($TenantId) {
    $fileName = "tenant_${TenantId}_${timestamp}.sql"
    $whereClause = "tenant_id = '$TenantId'"
    Write-Host "Creating tenant-scoped backup for $TenantId..." -ForegroundColor Cyan
}
else {
    $fileName = "full_${timestamp}.sql"
    Write-Host "Creating full database backup..." -ForegroundColor Cyan
}

$outputPath = Join-Path $OutputDir $fileName

# Build pg_dump command
$cmd = "pg_dump"
$cmd += " -h $SupabaseHost"
$cmd += " -U $Username"
$cmd += " -d $Database"
$cmd += " --no-owner --no-privileges --clean --if-exists"
$cmd += " --column-inserts"
$cmd += " -f `"$outputPath`""

if ($TenantId) {
    # For tenant-scoped, we need to filter each table
    # pg_dump doesn't support --where globally, so we dump each table separately
    Write-Host "Tenant-scoped backup requires per-table dump (slower)..." -ForegroundColor Yellow
    
    $allSql = @()
    $allSql += "-- Hasad ERP Tenant Backup: $TenantId"
    $allSql += "-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $allSql += ""
    
    foreach ($table in $tables) {
        Write-Host "  Dumping $table..." -NoNewline
        try {
            $tableCmd = "pg_dump -h $SupabaseHost -U $Username -d $Database -t $table --where=\"$whereClause\" --column-inserts --no-owner --no-privileges --clean --if-exists"
            $tableSql = & cmd /c "$env:PGPASSWORD=$Password; $tableCmd" 2>$null
            if ($tableSql.Trim()) {
                $allSql += $tableSql
                Write-Host " ✓" -ForegroundColor Green
            } else {
                Write-Host " (empty)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    $allSql | Out-File -FilePath $outputPath -Encoding UTF8
}
else {
    # Full backup
    Write-Host "Running pg_dump..." -ForegroundColor Cyan
    try {
        & cmd /c "$env:PGPASSWORD=$Password; $cmd" 2>$null
        Write-Host "Backup saved to: $outputPath" -ForegroundColor Green
    } catch {
        Write-Host "Backup failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Compress
if (Test-Path $outputPath) {
    Write-Host "Compressing..." -ForegroundColor Cyan
    Compress-Archive -Path $outputPath -DestinationPath "$outputPath.gz" -Force
    Remove-Item $outputPath -Force
    Write-Host "Compressed backup: $outputPath.gz" -ForegroundColor Green
    
    # Verify
    $size = (Get-Item "$outputPath.gz").Length / 1KB
    Write-Host "Size: $('{0:N1}' -f $size) KB" -ForegroundColor Cyan
}

# Cleanup old backups (keep last 30 days)
$cutoff = (Get-Date).AddDays(-30)
Get-ChildItem -Path $OutputDir -Filter "*.gz" | Where-Object { $_.LastWriteTime -lt $cutoff } | Remove-Item -Force
Write-Host "Cleaned up backups older than 30 days." -ForegroundColor Cyan