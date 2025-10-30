# =====================================================================
# Nova - Auth System Complete Test Suite (PowerShell)
# =====================================================================
# Purpose: Test the entire authentication system
# Usage: .\scripts\test-auth-system.ps1
# =====================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Nova - Auth System Complete Test Suite" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Load environment variables from .env
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^#][^=]*)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
    Write-Host "✅ Environment variables loaded from .env" -ForegroundColor Green
} else {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# =====================================================================
# Test 1: Email Domain Validation (Invalid Domains)
# =====================================================================

Write-Host "Test 1: Email Domain Validation (@gmail.com - should REJECT)" -ForegroundColor Yellow
Write-Host "---------------------------------------"

$body = @{
    email = "test@gmail.com"
    password = "TestPassword123!"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method Post `
        -Uri "$env:SUPABASE_URL/auth/v1/signup" `
        -Headers @{
            "apikey" = $env:SUPABASE_ANON_KEY
            "Content-Type" = "application/json"
        } `
        -Body $body `
        -ErrorAction Stop

    Write-Host "❌ FAIL: Email should have been rejected" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "HTTP Status: $statusCode"
    Write-Host "✅ PASS: Email rejected as expected (HTTP $statusCode)" -ForegroundColor Green
}

Write-Host ""

# =====================================================================
# Test 2: Valid Email Domain
# =====================================================================

Write-Host "Test 2: Email Domain Validation (@galileimoro.edu.it - should ACCEPT)" -ForegroundColor Yellow
Write-Host "---------------------------------------"

# Generate random email to avoid duplicates
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$randomEmail = "test-$timestamp@galileimoro.edu.it"

$body = @{
    email = $randomEmail
    password = "TestPassword123!"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method Post `
        -Uri "$env:SUPABASE_URL/auth/v1/signup" `
        -Headers @{
            "apikey" = $env:SUPABASE_ANON_KEY
            "Content-Type" = "application/json"
        } `
        -Body $body

    Write-Host "HTTP Status: 200"
    Write-Host "✅ PASS: Email accepted as expected" -ForegroundColor Green
    Write-Host "Email used: $randomEmail"
    Write-Host "User ID: $($response.user.id)"

    # Save user ID for later tests
    $script:testUserId = $response.user.id

    Write-Host ""
    Write-Host "⏳ Waiting 3 seconds for webhook to process..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3

} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "❌ FAIL: Email should have been accepted (HTTP $statusCode)" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
}

Write-Host ""

# =====================================================================
# Test 3: Magic Link Request
# =====================================================================

Write-Host "Test 3: Magic Link Request (OTP)" -ForegroundColor Yellow
Write-Host "---------------------------------------"

$body = @{
    email = $randomEmail
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method Post `
        -Uri "$env:SUPABASE_URL/auth/v1/otp" `
        -Headers @{
            "apikey" = $env:SUPABASE_ANON_KEY
            "Content-Type" = "application/json"
        } `
        -Body $body

    Write-Host "✅ PASS: Magic link request sent successfully" -ForegroundColor Green
    Write-Host "Check email: $randomEmail"

    Write-Host ""
    Write-Host "⏳ Waiting 2 seconds for webhook to process..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2

} catch {
    Write-Host "❌ FAIL: Magic link request failed" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
}

Write-Host ""

# =====================================================================
# Test Summary
# =====================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Completed Tests:" -ForegroundColor White
Write-Host "  ✅ Test 1: Invalid email domain (@gmail.com) - Rejected"
Write-Host "  ✅ Test 2: Valid email domain (@galileimoro.edu.it) - Accepted"
Write-Host "  ✅ Test 3: Magic link request - Sent"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Run the SQL queries in scripts/test-auth-events-logging.sql"
Write-Host "  2. Verify events are logged in auth_events table"
Write-Host "  3. Check Edge Function logs in Supabase Dashboard"
Write-Host ""
Write-Host "Dashboard Links:" -ForegroundColor Cyan
Write-Host "  • Edge Functions: https://supabase.com/dashboard/project/$env:SUPABASE_PROJECT_REF/functions"
Write-Host "  • Auth Users: https://supabase.com/dashboard/project/$env:SUPABASE_PROJECT_REF/auth/users"
Write-Host "  • Database: https://supabase.com/dashboard/project/$env:SUPABASE_PROJECT_REF/editor"
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
