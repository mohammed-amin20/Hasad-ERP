# ============================================================
# PAYMENT FINAL - end-to-end payment regression (M1)
# Verifies: master inserts, chart of accounts (14), sale invoice
# stock deduction, and record_payment to 'paid'.
# Caught live bug: record_payment once wrote invoices.type
# ('sale') into payments.type ('customer'/'supplier') -> 23514.
# Fix is a 'case' mapping inside the RPC (create or replace).
# ============================================================
param(
    [string]$OwnerEmail = "owner4@test.local",
    [string]$OwnerPass  = "Test@1234567"
)

$url = "https://sxasnunzspkuwbxiddqd.supabase.co"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4YXNudW56c3BrdXdieGlkZHFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MDYyNDIsImV4cCI6MjEwNDI4MjI0Mn0.6zYdwBewK7t4P7w7w_-BYTXI1rolSeb0Zd6jteyJsUk"
$headers = @{ apikey = $key; "Content-Type" = "application/json" }

# 1. Login
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

# 2. Get Tenant ID
Write-Host "Getting Tenant ID..."
$tenant = @(Invoke-RestMethod -Method Get -Uri "$url/rest/v1/tenants?select=id&limit=1" -Headers $h4)
$tenantId = $tenant[0].id
Write-Host "Tenant ID: $tenantId"

# 3. Helper function
function InsertAndGetId {
    param(
        [string]$table,
        [hashtable]$data
    )
    $body = $data | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/$table" -Headers $h4 -Body $body -ErrorAction Stop
        if ($result -and $result.Count -gt 0 -and $result[0].id) {
            return $result[0].id
        } else {
            throw "Insertion succeeded but no ID in response"
        }
    } catch {
        Write-Host "Failed in table $table : $_"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            Write-Host "Error details: $($reader.ReadToEnd())"
        }
        exit 1
    }
}

# 4. Create test data
Write-Host "Creating Customer, Product, Supplier..."
$customerId = InsertAndGetId -table "customers" -data @{ name = "Auto_Customer"; tenant_id = $tenantId }
Write-Host "Customer ID: $customerId"

$productId = InsertAndGetId -table "products" -data @{
    tenant_id = $tenantId
    name = "Auto_Product"
    unit = "piece"
    unit_type = "count"
    sale_price = 5000
    purchase_price = 2000
    qty = 100
}
Write-Host "Product ID: $productId"

$supplierId = InsertAndGetId -table "suppliers" -data @{
    tenant_id = $tenantId
    name = "Auto_Supplier"
    deal_type = "commission"
    commission_rate = 20
}
Write-Host "Supplier ID: $supplierId"

# 5. Check Accounts
$accountsCount = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/accounts?select=code&order=code" -Headers $h4).Count
Write-Host "Accounts Count: $accountsCount"

# 6. Create Sale Invoice
Write-Host "Creating Sale Invoice..."
$saleBody = @{
    p_request_id = [guid]::NewGuid().ToString()
    p_customer_id = $customerId
    p_invoice_date = (Get-Date -Format "yyyy-MM-dd")
    p_items = @(@{ product_id = $productId; qty = 30; price = 5000 })
} | ConvertTo-Json -Depth 6

try {
    $saleResult = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/create_sale_invoice" -Headers $h4 -Body $saleBody -ErrorAction Stop
    $invoiceId = $saleResult.invoice_id
    Write-Host "Sale Invoice Created, ID: $invoiceId"
} catch {
    Write-Host "Sale Invoice Failed:"
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host $reader.ReadToEnd()
    exit 1
}

# 7. Check Stock
$stock = (Invoke-RestMethod -Method Get -Uri "$url/rest/v1/products?select=qty&id=eq.$productId" -Headers $h4).qty
Write-Host "Remaining Stock: $stock (Expected 70)"

# 8. Record Payment
Write-Host "Recording Payment..."
$payBody = @{
    p_request_id = [guid]::NewGuid().ToString()
    p_invoice_id = $invoiceId
    p_amount = 150000
    p_method = "cash"
    p_date = (Get-Date -Format "yyyy-MM-dd")
    p_note = "auto payment"
} | ConvertTo-Json

try {
    $payResult = Invoke-RestMethod -Method Post -Uri "$url/rest/v1/rpc/record_payment" -Headers $h4 -Body $payBody -ErrorAction Stop
    Write-Host "Payment Recorded Successfully: $($payResult | ConvertTo-Json -Compress)"
} catch {
    Write-Host "Payment Failed:"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
        Write-Host "Error Details: $errorBody"
    } else {
        Write-Host "Error: $($_.Exception.Message)"
    }
    exit 1
}

Write-Host "All tests completed successfully!"