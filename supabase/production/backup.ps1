<#
.SYNOPSIS
    Backup Hasad ERP production database (full or tenant-scoped).

.DESCRIPTION
    Uses pg_dump to create SQL backups. Requires PostgreSQL client tools installed
    (pg_dump >= 15 so the tenant-scoped path can use --on-conflict-do-nothing;
    the script retries without that flag if the client is older).

    FIXES vs earlier draft (committed d25dc1a era):
      * PGPASSWORD is set on the current process (the old `cmd /c "$env:PGPASSWORD=$Password; ..."`
        expanded to an EMPTY password then ran pg_dump - broken credentials).
      * Real gzip via System.IO.Compression.GZipStream. The old Compress-Archive
        produced a ZIP file misnamed ".gz", which pg_restore/psql tooling and
        gunzip cannot read.
      * Tenant-scoped dumps are now DATA-ONLY (--data-only --column-inserts
        [--on-conflict-do-nothing]) and NEVER pass --clean/--if-exists. The old
        per-table `-t t --clean` emitted DROP TABLE, so restoring a tenant backup
        onto a live DB would DELETE other tenants' tables entirely.
      * stderr is captured and surfaced instead of 2>$null.

.PARAMETER SupabaseHost
    Database host from Supabase Settings -> Database (e.g., db.xxxxx.supabase.co)

.PARAMETER Database
    Database name (usually 'postgres')

.PARAMETER Username
    Database user (usually 'postgres')

.PARAMETER Password
    Database password (from Supabase Settings -> Database)

.PARAMETER TenantId
    Optional: specific tenant UUID for tenant-scoped backup

.PARAMETER OutputDir
    Directory to save backup files (default: ./backups)

.EXAMPLE
    # Full backup
    .\backup.ps1 -SupabaseHost "db.xxxxx.supabase.co" -Password "xxx"

    # Tenant-scoped backup (safe to restore over a live DB)
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

$ErrorActionPreference = "Stop"

# Create output directory
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$tables = @(
    'tenants', 'users', 'user_tenants', 'customers', 'suppliers', 'products',
    'invoices', 'invoice_items', 'payments', 'journal_entries', 'journal_entry_lines',
    'commission_dues', 'employees', 'salaries', 'employee_movements', 'stock_moves',
    'expenses', 'accounts', 'reminder_log', 'tenant_settings', 'invoice_counters',
    'processed_requests'
)

if ($TenantId) {
    $fileName = "tenant_${TenantId}_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql.gz"
    Write-Host "Creating tenant-scoped backup for $TenantId..." -ForegroundColor Cyan
}
else {
    $fileName = "full_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql.gz"
    Write-Host "Creating full database backup..." -ForegroundColor Cyan
}

# pg_dump needs the password as an env var. Set it on THIS process (the old
# approach embedded `$env:PGPASSWORD=$Password` inside a cmd /c string, which
# PowerShell expanded to an empty value).
$env:PGPASSWORD = $Password

function Invoke-PgDump([string[]]$ArgsArray) {
    $out = & pg_dump @ArgsArray 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host "  pg_dump exited $code" -ForegroundColor Red
        $out | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
        return $false
    }
    return $true
}

$sqlPath = Join-Path $OutputDir ([System.IO.Path]::GetFileNameWithoutExtension($fileName))

try {
    if ($TenantId) {
        # DATA-ONLY tenant backup: pure INSERTs, no DDL, NEVER --clean.
        # Restoring is idempotent (on-conflict-do-nothing) and cannot touch
        # other tenants' rows. pg_dump >=15 needed for the flag; older clients
        # retry without it.
        $allSql = New-Object System.Collections.Generic.List[string]
        $allSql.Add("-- Hasad ERP Tenant Backup: $TenantId")
        $allSql.Add("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $allSql.Add("-- Data-only, idempotent. Safe to run against a live database.")
        $allSql.Add("")

        foreach ($table in $tables) {
            Write-Host "  Dumping $table..." -NoNewline
            $baseArgs = @('-h', $SupabaseHost, '-U', $Username, '-d', $Database,
                          '--no-owner', '--no-privileges',
                          '-t', $table, '--data-only', '--column-inserts')
            $ok = $false
            $attempt = 0
            $maxTries = 2
            $errLines = $null

            for ($i = 0; $i -lt $maxTries -and -not $ok; $i++) {
                $attempt = $i + 1
                $args2 = @($baseArgs)
                if ($attempt -eq 1) {
                    $args2 += '--on-conflict-do-nothing'
                }
                $args2 += '--where=' + "tenant_id = '$TenantId'"
                $errLines = & pg_dump @args2 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $ok = $true
                } elseif ($attempt -eq 1 -and (($errLines | Out-String) -match 'on-conflict-do-nothing')) {
                    # Older pg_dump does not know the flag -> retry without it.
                    Write-Host " (pg_dump <15, retrying without --on-conflict-do-nothing)" -NoNewline
                } else {
                    break
                }
            }

            if ($ok) {
                foreach ($line in $errLines) { $allSql.Add($line) }
                $allSql.Add("")
                Write-Host " OK" -ForegroundColor Green
            } else {
                $errLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
                Write-Host " FAILED" -ForegroundColor Red
            }
        }

        [System.IO.File]::WriteAllLines($sqlPath, $allSql, [System.Text.UTF8Encoding]::new($false))
    }
    else {
        # Full backup: schema + data, clean/if-exists makes restore-to-empty or
        # replace straight-forward. Column-inserts keeps it diffable.
        Write-Host "Running pg_dump..." -ForegroundColor Cyan
        $args3 = @('-h', $SupabaseHost, '-U', $Username, '-d', $Database,
                   '--no-owner', '--no-privileges', '--clean', '--if-exists',
                   '--column-inserts', '-f', $sqlPath)
        if (-not (Invoke-PgDump $args3)) {
            exit 1
        }
    }
    Write-Host "Backup written to: $sqlPath" -ForegroundColor Green

    # Real gzip (GZipStream) - NOT Compress-Archive (that mades a ZIP named .gz).
    $gzPath = Join-Path $OutputDir $fileName
    $inStream  = [System.IO.File]::OpenRead($sqlPath)
    $outStream = [System.IO.File]::Create($gzPath)
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($outStream, [System.IO.Compression.CompressionMode]::Compress)
        try { $inStream.CopyTo($gzip) }
        finally { $gzip.Dispose() }
    } finally {
        $outStream.Dispose()
        $inStream.Dispose()
    }
    Remove-Item -LiteralPath $sqlPath -Force

    $size = (Get-Item -LiteralPath $gzPath).Length / 1KB
    Write-Host "Compressed backup: $gzPath" -ForegroundColor Green
    Write-Host "Size: $('{0:N1}' -f $size) KB" -ForegroundColor Cyan

    # Cleanup old backups (keep last 30 days)
    $cutoff = (Get-Date).AddDays(-30)
    Get-ChildItem -LiteralPath $OutputDir -Filter "*.gz" |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force
    Write-Host "Cleaned up backups older than 30 days." -ForegroundColor Cyan
}
finally {
    $env:PGPASSWORD = $null
}