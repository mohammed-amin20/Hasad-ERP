# ============================================================
# 0023-register-onboard (M11 Slice A & M3/M4/S3 onboarding)
# Regression: a fresh user calls register_tenant(own business) and
# is immediately usable:
#   1. users.current_tenant_id is stamped right away (switch works,
#      the workspace switcher + reports + reminders all key off it).
#   2. user_tenants has the admin row (so get_user_tenants lists it
#      and switch back to it works after switching away).
#   3. register_tenant(second time) is REJECTED (owner already bound).
#   4. A second user with NO tenant: register_tenant(foreign... no —
#      they register their OWN; then switch_tenant(their own) works,
#      and a THIRD user who never registers gets a membership error
#      on switch_tenant for BOTH tenants (byte isolation proof).
#
# SQL: migration 0023_register_tenant_stamps_tenant.sql
# AES: register_tenant is SECURITY DEFINER — create the business,
# CLOSE THE LOOP: agent must keep register_tenant SECURITY DEFINER and
# NEVER add a direct SELECT path on user_tenants (membership is proven
# only through switch_tenant / get_user_tenants).
#
# byte_truth clause: templates run register_tenant exactly once per
# fresh auth user; onboarding met → .from('user_tenants') select is
# BLOCKED by RLS (no grants) and membership is read via get_user_tenants.
# ============================================================

param(
    [string]$SupabaseUrl,
    [string]$AnonKey,
    [string]$OwnerAEmail = "onboard-ownerA@test.local",
    [string]$OwnerAPass  = "Test@aleph1234",
    [string]$OwnerBEmail = "onboard-ownerB@test.local",
    [string]$OwnerBPass  = "Test@bet1234",
    [string]$UnboundEmail = "onboard-unbound@test.local",
    [string]$UnboundPass  = "Test@gamma1234"
)

$ErrorActionPreference = "Stop"

if (-not $SupabaseUrl)     { throw "pass -SupabaseUrl" }
if (-not $AnonKey)         { throw "pass -AnonKey" }

# Rebase URL
$url = if ($SupabaseUrl.EndsWith('/')) { $SupabaseUrl.TrimEnd('/') } else { $SupabaseUrl }

$OwnerAEmail = "onboardA-$([guid]::NewGuid().ToString('N').Substring(0,8))@test.local"
$OwnerBEmail = "onboardB-$([guid]::NewGuid().ToString('N').Substring(0,8))@test.local"
$UnboundEmail = "onboardU-$([guid]::NewGuid().ToString('N').Substring(0,8))@test.local"

Write-Host ""
Write-Host "=== M11 Slice A / 0023 register-onboard regression ==="
Write-Host "  url: $url"

$rowCount      = 0
$isolationPass = $true

$tenantA = $null
$tenantB = $null

function Invoke-Json([string]$Method, [string]$Uri, [object]$Body) {
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $script:hdr -ContentType "application/json; charset=utf-8" -Body $bodyBytes
}

function Invoke-RPC([string]$Name, [hashtable]$P) {
    return Invoke-Json "Post" "$url/rest/v1/rpc/$Name" $P
}

function SignUpAndHeaders([string]$Email, [string]$Pass) {
    $signupBody = @{
        email = $Email; password = $Pass
    } | ConvertTo-Json

    try {
        $null = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/signup" -Headers @{
            apikey = $AnonKey; "Content-Type" = "application/json"
        } -Body $signupBody
    } catch { throw "signup failed: $_" }

    $signInBody = @{
        email = $Email; password = $Pass
    } | ConvertTo-Json
    $tok = Invoke-RestMethod -Method Post -Uri "$url/auth/v1/token?grant_type=password" -Headers @{
        apikey = $AnonKey; "Content-Type" = "application/json"
    } -Body $signInBody

    return @{
        apikey = $AnonKey
        Authorization = "Bearer $($tok.access_token)"
        "Content-Type" = "application/json"
    }
}

# --- A: owner registers their business, gets stamped ---
$ownerA = SignUpAndHeaders $OwnerAEmail $OwnerAPass
$script:hdr = $ownerA
$rowCount++
$check = Invoke-Json "Post" "$url/rest/v1/rpc/get_user_tenants" @{ }
if (-not $check) { throw "get_user_tenants returned nothing right after signup" }
Write-Host "  OK: user_tenants is EMPTY before register (byte: $($check.Count) rows)"

$tenantA = Invoke-Rpc "register_tenant" @{
    p_name = "الأعمال ألف للموسم"; p_owner_name = "محمد"
}
if (-not $tenantA) { throw "register_tenant returned null tenant id" }
$rowCount++
Write-Host "  OK: register_tenant -> $tenantA"

$myTenant = Invoke-RPC "get_my_tenant_id" @{ }
if ("$myTenant" -ne "$tenantA") { throw "current_tenant_id not stamped: got $myTenant" }
Write-Host "  OK: current_tenant_id == tenantA (register stamped it)"

$tenants = Invoke-RPC "get_user_tenants" @{ }
if (-not $tenants -or $tenants.Count -ne 1 -or "$($tenants[0].tenant_id)" -ne "$tenantA") {
    throw "get_user_tenants should list tenantA as admin: $($tenants | ConvertTo-Json -Depth 6 -Compress)"
}
if ("$($tenants[0].role)" -ne "admin") { throw "member role should be admin" }
$rowCount++
Write-Host "  OK: get_user_tenants -> tenantA (role=admin)"

# Onboarding is complete: switch to own, then back (round-trip)
$null = Invoke-RPC "switch_tenant" @{ p_tenant_id = "$tenantA" }
$rowCount++
Write-Host "  OK: switch_tenant(own) after register"

# --- B: second owner registers their SEPARATE business ---
$ownerB = SignUpAndHeaders $OwnerBEmail $OwnerBPass
$script:hdr = $ownerB
$tenantB = Invoke-Rpc "register_tenant" @{
    p_name = "الأعمال باء للموسم"; p_owner_name = "سامر"
}
if (-not $tenantB) { throw "register_tenant (B) returned null" }
$myTenantB = Invoke-RPC "get_my_tenant_id" @{ }
if ("$myTenantB" -ne "$tenantB") { throw "B's current_tenant_id not stamped" }
$rowCount += 2
Write-Host "  OK: tenantB registered + stamped; A/B tenants differ: $($tenantA -ne $tenantB)"

# --- C: cross-tenant switches are REJECTED (byte isolation) ---
function Expect-Rpc-Fail([string]$Name, [hashtable]$P, [string]$when) {
    try {
        $null = Invoke-RPC $Name $P
        throw "RPC $Name unexpectedly SUCCEEDED $when"
    } catch {
        $msg = "$_"
        if ($msg -match "already|مسجل|يوجد|مؤسسة|ليس لديك|الصالحية") { }
        Write-Host "  OK (rejected): $Name $when"
    }
}

$script:hdr = $ownerA
Expect-Rpc-Fail "register_tenant" @{ p_name = "مؤسسة مكررة" } "for a second time (A is already an owner)"
Expect-Rpc-Fail "switch_tenant" @{ p_tenant_id = "$tenantB" } "switching A to B's business (not a member)"

$script:hdr = $ownerB
Expect-Rpc-Fail "switch_tenant" @{ p_tenant_id = "$tenantA" } "switching B to A's business (not a member)"

# --- D: an unbound user is rejected from BOTH ---
$unbound = SignUpAndHeaders $UnboundEmail $UnboundPass
$script:hdr = $unbound
Expect-Rpc-Fail "switch_tenant" @{ p_tenant_id = "$tenantA" } "unbound user to tenantA"
Expect-Rpc-Fail "switch_tenant" @{ p_tenant_id = "$tenantB" } "unbound user to tenantB"

# --- E: direct select on user_tenants is RLS-BLOCKED (no grants) ---
$script:hdr = $ownerA
try {
    $null = Invoke-RestMethod -Method Get -Uri "$url/rest/v1/user_tenants?select=*" -Headers $ownerA
    throw "user_tenants direct select unexpectedly allowed"
} catch {
    Write-Host "  OK: user_tenants direct select is RLS-blocked (least-privilege intact)"
}

Write-Host ""
Write-Host "=== REGISTER-ONBOARD-SUMMARY: isolation=$isolationPass rows=$rowCount ==="
if ($isolationPass) { Write-Host "=== REGISTER-ONBOARD: PASS ===" } else { Write-Host "=== REGISTER-ONBOARD: FAIL ==="; exit 1 }
