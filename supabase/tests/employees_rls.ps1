# ============================================================
# EMPLOYEES RLS + SALARY RPC - end-to-end regression (M6 slice A)
# Verifies: migration 0016 applied (employees CRUD via RLS works
# from the app role) and the security-invoker salary RPC
# (get_employee_entitlement) can now select from employees at runtime.
# Run AFTER pasting 0016_employees_rls.sql in the SQL Editor.
# ============================================================
param(
    [string]$OwnerEmail = "owner4@test.local",
    [string]$OwnerPass  = "Test@1234567"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

Write-Host "Logging in..."
$loginBody = @{ email = $OwnerEmail; password = $OwnerPass } | ConvertTo-Json
$resp = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers $headers -Body $loginBody
$h4 = @{
    apikey = $key
    Authorization = "Bearer " + $resp.access_token
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}
Write-Host "Login successful"

function Invoke-RPC {
    param([string]$name, [hashtable]$p)
    $body = $p | ConvertTo-Json
    return Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/$name" -Headers $h4 -Body $body
}

# --- Case 1: create employee via plain table access (RLS INSERT grant) ---
Write-Host "Case 1: create employee via .from('employees') ..."
$empBody = @{
    name        = "موظف اختبار $([guid]::NewGuid())"
    job_title   = "محاسب"
    phone       = "0599000000"
    base_salary = 200000
} | ConvertTo-Json
$emp = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/employees" -Headers $h4 -Body $empBody
$empId = $emp[0].id
if (-not $empId) { throw "Case 1: employee insert failed" }
if ([int]$emp[0].base_salary -ne 200000) { throw "Case 1: base_salary not saved" }
Write-Host "  created id=$empId"

# --- Case 2: read back (RLS SELECT grant) ---
Write-Host "Case 2: select employee ..."
$read = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/employees?select=*&id=eq.$empId" -Headers $h4
if ($read.Count -ne 1 -or $read[0].name -ne $emp[0].name) { throw "Case 2: read-back failed" }
Write-Host "  name=$($read[0].name) job=$($read[0].job_title)"

# --- Case 3: salary RPC can now select employees (permission fix) ---
Write-Host "Case 3: get_employee_entitlement on fresh employee ..."
$ent = Invoke-RPC -name "get_employee_entitlement" -p @{
    p_employee_id = $empId
    p_month       = "2026-09-01"
}
if ([int]$ent.base_salary -ne 200000) { throw "Case 3: base_salary mismatch, got $($ent.base_salary)" }
if ([int]$ent.net_due -ne 200000) { throw "Case 3: net_due should equal base for a fresh employee, got $($ent.net_due)" }
Write-Host "  base=$($ent.base_salary) net_due=$($ent.net_due)"

# --- Case 4: update employee (RLS UPDATE grant) ---
Write-Host "Case 4: update phone + job_title ..."
$updBody = @{ phone = "0599111122"; job_title = "أمين مخزن" } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$url/rest/v1/employees?id=eq.$empId" -Headers $h4 -Body $updBody | Out-Null
$read2 = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/employees?select=phone,job_title&id=eq.$empId" -Headers $h4
if ($read2[0].phone -ne "0599111122" -or $read2[0].job_title -ne "أمين مخزن") { throw "Case 4: update failed" }
Write-Host "  updated ok"

# --- Case 5: delete employee (RLS DELETE grant) ---
Write-Host "Case 5: delete employee ..."
Invoke-RestMethod -Method Delete -Uri "$url/rest/v1/employees?id=eq.$empId" -Headers $h4 | Out-Null
$gone = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/employees?select=id&id=eq.$empId" -Headers $h4
if ($gone.Count -ne 0) { throw "Case 5: delete failed" }
Write-Host "  deleted ok"

Write-Host "`nALL EMPLOYEES RLS TESTS PASSED"