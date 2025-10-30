#!/bin/bash
# =====================================================================
# Test Auth Hook Email Domain Validation
# =====================================================================
# Purpose: Verify that only @galileimoro.edu.it emails are allowed
# Usage: bash scripts/test-auth-hook-validation.sh
# =====================================================================

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
fi

echo "========================================="
echo "Test Auth Hook Email Domain Validation"
echo "========================================="
echo ""

# Test 1: Invalid domain (@gmail.com) - SHOULD FAIL
echo "Test 1: Signup with @gmail.com (should be REJECTED)"
echo "---------------------------------------"

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "${SUPABASE_URL}/auth/v1/signup" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@gmail.com",
    "password": "TestPassword123!"
  }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "HTTP Status: $HTTP_STATUS"
echo "Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" = "400" ] || [ "$HTTP_STATUS" = "403" ]; then
  echo "✅ PASS: Email rejected as expected"
else
  echo "❌ FAIL: Email should have been rejected (got HTTP $HTTP_STATUS)"
fi

echo ""
echo "---------------------------------------"
echo ""

# Test 2: Invalid domain (@yahoo.com) - SHOULD FAIL
echo "Test 2: Signup with @yahoo.com (should be REJECTED)"
echo "---------------------------------------"

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "${SUPABASE_URL}/auth/v1/signup" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "student@yahoo.com",
    "password": "TestPassword123!"
  }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "HTTP Status: $HTTP_STATUS"
echo "Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" = "400" ] || [ "$HTTP_STATUS" = "403" ]; then
  echo "✅ PASS: Email rejected as expected"
else
  echo "❌ FAIL: Email should have been rejected (got HTTP $HTTP_STATUS)"
fi

echo ""
echo "---------------------------------------"
echo ""

# Test 3: Valid domain (@galileimoro.edu.it) - SHOULD SUCCEED
echo "Test 3: Signup with @galileimoro.edu.it (should be ACCEPTED)"
echo "---------------------------------------"

# Generate random email to avoid duplicates
RANDOM_EMAIL="test-$(date +%s)@galileimoro.edu.it"

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "${SUPABASE_URL}/auth/v1/signup" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"${RANDOM_EMAIL}\",
    \"password\": \"TestPassword123!\"
  }")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "HTTP Status: $HTTP_STATUS"
echo "Response: $RESPONSE_BODY"
echo "Email used: $RANDOM_EMAIL"

if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ PASS: Email accepted as expected"
  echo ""
  echo "🔍 User ID created: $(echo "$RESPONSE_BODY" | grep -oP '"id":"[^"]*"' | cut -d'"' -f4)"
else
  echo "❌ FAIL: Email should have been accepted (got HTTP $HTTP_STATUS)"
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""
echo "Expected Results:"
echo "  • Test 1 (@gmail.com): ✅ Rejected"
echo "  • Test 2 (@yahoo.com): ✅ Rejected"
echo "  • Test 3 (@galileimoro.edu.it): ✅ Accepted"
echo ""
echo "========================================="
