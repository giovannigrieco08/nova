#!/bin/bash
# Supabase Configuration Verification Script
# Purpose: Verify .env exists, is git-ignored, and Supabase auth is configured correctly
# Usage: bash scripts/verify_supabase_config.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Nova - Supabase Configuration Verification"
echo "================================================"
echo ""

# Check 1: .env file exists
echo -n "✓ Checking .env file exists... "
if [ ! -f .env ]; then
    echo -e "${RED}FAIL${NC}"
    echo "  → .env file not found. Run: cp .env.example .env"
    exit 1
fi
echo -e "${GREEN}PASS${NC}"

# Check 2: .env is git-ignored
echo -n "✓ Checking .env is git-ignored... "
if git check-ignore .env > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  → .env is NOT git-ignored. Add '.env' to .gitignore"
    exit 1
fi

# Check 3: Load environment variables
echo -n "✓ Loading environment variables... "
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

# Check 4: Required variables are set
echo "✓ Checking required environment variables..."
REQUIRED_VARS=("SUPABASE_PROJECT_REF" "SUPABASE_URL" "SUPABASE_ANON_KEY" "SUPABASE_SERVICE_ROLE_KEY" "SUPABASE_ACCESS_TOKEN")
ALL_VARS_SET=true

for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        echo -e "  ${RED}✗${NC} $VAR is not set"
        ALL_VARS_SET=false
    else
        # Show first 20 chars for verification (don't expose full keys)
        VAR_VALUE="${!VAR}"
        PREVIEW="${VAR_VALUE:0:20}..."
        echo -e "  ${GREEN}✓${NC} $VAR: $PREVIEW"
    fi
done

if [ "$ALL_VARS_SET" = false ]; then
    echo -e "${RED}FAIL${NC} - Missing required environment variables"
    exit 1
fi

# Check 5: Supabase project is accessible
echo -n "✓ Checking Supabase project accessibility... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/config/auth")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL (HTTP $HTTP_CODE)${NC}"
    echo "  → Check SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF"
    exit 1
fi

# Check 6: Magic link expiration configuration
echo -n "✓ Checking magic link expiration (MAILER_OTP_EXP)... "
AUTH_CONFIG=$(curl -s \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/config/auth")

MAILER_OTP_EXP=$(echo "$AUTH_CONFIG" | grep -oP '"mailer_otp_exp":\K\d+')

if [ "$MAILER_OTP_EXP" = "900" ]; then
    echo -e "${GREEN}PASS${NC} (900 seconds / 15 minutes)"
else
    echo -e "${YELLOW}WARN${NC} (Current: $MAILER_OTP_EXP seconds, Expected: 900)"
    echo "  → Run: curl -X PATCH \"https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/config/auth\" \\"
    echo "           -H \"Authorization: Bearer \$SUPABASE_ACCESS_TOKEN\" \\"
    echo "           -H \"Content-Type: application/json\" \\"
    echo "           -d '{\"mailer_otp_exp\": 900}'"
fi

# Check 7: Email provider enabled
echo -n "✓ Checking email provider enabled... "
EMAIL_ENABLED=$(echo "$AUTH_CONFIG" | grep -oP '"external_email_enabled":\K(true|false)')

if [ "$EMAIL_ENABLED" = "true" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  → Enable email provider in Supabase Dashboard:"
    echo "     https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF/auth/providers"
    exit 1
fi

# Check 8: Refresh token rotation enabled
echo -n "✓ Checking refresh token rotation... "
ROTATION_ENABLED=$(echo "$AUTH_CONFIG" | grep -oP '"refresh_token_rotation_enabled":\K(true|false)')

if [ "$ROTATION_ENABLED" = "true" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}WARN${NC}"
    echo "  → Refresh token rotation should be enabled for security"
fi

# Check 9: JWT expiration
echo -n "✓ Checking JWT expiration... "
JWT_EXP=$(echo "$AUTH_CONFIG" | grep -oP '"jwt_exp":\K\d+')
echo -e "${GREEN}INFO${NC} ($JWT_EXP seconds / $(($JWT_EXP / 60)) minutes)"

# Manual configuration reminder
echo ""
echo "================================================"
echo -e "${YELLOW}MANUAL CONFIGURATION REQUIRED${NC}"
echo "================================================"
echo ""
echo "The following settings must be configured manually in the Supabase Dashboard:"
echo ""
echo "1. Refresh Token Expiration (30 days):"
echo "   → Navigate to: Authentication → Settings → Session Settings"
echo "   → Set 'Refresh token time to live' to: 2592000 seconds"
echo "   → URL: https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF/auth/settings"
echo ""
echo "2. Site URL (for deep linking):"
echo "   → Navigate to: Authentication → URL Configuration"
echo "   → Site URL: https://nova.galileimoro.edu.it"
echo "   → Redirect URLs: Add https://nova.galileimoro.edu.it/auth/confirm"
echo "   → URL: https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF/auth/url-configuration"
echo ""

# Success summary
echo "================================================"
echo -e "${GREEN}✓ Verification Complete${NC}"
echo "================================================"
echo ""
echo "Summary:"
echo "  ✓ Environment file configured correctly"
echo "  ✓ Git security verified (.env is ignored)"
echo "  ✓ Supabase project accessible"
echo "  ✓ Magic link expiration: $MAILER_OTP_EXP seconds"
echo "  ✓ Email provider: enabled"
echo "  ⚠ Manual dashboard configuration still required (see above)"
echo ""
echo "Next steps:"
echo "  1. Complete manual dashboard configuration (Site URL, Refresh token expiry)"
echo "  2. Run /speckit.tasks to generate implementation task breakdown"
echo "  3. Deploy database schema (contracts/database.sql)"
echo "  4. Configure Auth Hooks for email domain validation"
echo ""
