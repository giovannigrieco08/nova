# Supabase Credentials Management

**SECURITY NOTICE**: This document explains credential management for the Nova project. Never commit actual credentials to Git.

## Credential Types

### 1. Anon Key (Public Key)
- **Location**: `.env` → `SUPABASE_ANON_KEY`
- **Security Level**: Public - Safe to expose in Flutter client code
- **Purpose**: Client-side API authentication
- **RLS**: Respects Row-Level Security policies
- **Usage**:
  - Flutter app initialization
  - Supabase client instantiation
  - All user-facing authentication flows

### 2. Service Role Key (Secret Key)
- **Location**: `.env` → `SUPABASE_SERVICE_ROLE_KEY`
- **Security Level**: SECRET - NEVER expose in client code
- **Purpose**: Backend/admin operations that bypass RLS
- **RLS**: Bypasses all Row-Level Security policies
- **Usage**:
  - Admin scripts (database migrations, bulk operations)
  - Backend services (if we add Node.js backend later)
  - Local development database scripts
- **⚠️ WARNING**: This key grants full database access. Never commit to Git.

### 3. Personal Access Token
- **Location**: `.env` → `SUPABASE_ACCESS_TOKEN`
- **Security Level**: SECRET - Personal credential
- **Purpose**: Supabase Management API configuration
- **Scope**: Project settings, auth configuration, infrastructure changes
- **Usage**:
  - Configure auth settings (magic link expiration, session duration)
  - Manage database migrations via CLI
  - CI/CD pipeline automation (use separate token per environment)
- **Generation**: https://supabase.com/dashboard/account/tokens
- **⚠️ WARNING**: Tied to your Supabase account. Do not share or commit.

## Setup Instructions

### First-Time Setup

1. **Copy the template file**:
   ```bash
   cp .env.example .env
   ```

2. **Get credentials from Supabase Dashboard**:
   - Navigate to: https://supabase.com/dashboard/project/jhnxscorszeslkhnxtif/settings/api
   - Copy:
     - Project URL
     - Project Reference ID
     - Anon (public) key
     - Service Role (secret) key

3. **Generate Personal Access Token**:
   - Navigate to: https://supabase.com/dashboard/account/tokens
   - Click "Generate new token"
   - Name: `Nova Development`
   - Scopes: Select all (or minimum: project read/write)
   - Copy the token immediately (shown only once)

4. **Fill `.env` file**:
   ```env
   SUPABASE_PROJECT_REF=jhnxscorszeslkhnxtif
   SUPABASE_URL=https://jhnxscorszeslkhnxtif.supabase.co
   SUPABASE_ANON_KEY=<paste-anon-key>
   SUPABASE_SERVICE_ROLE_KEY=<paste-service-role-key>
   SUPABASE_ACCESS_TOKEN=<paste-personal-token>
   ```

5. **Verify `.env` is git-ignored**:
   ```bash
   git check-ignore .env
   # Should output: .env
   ```

### Team Onboarding

When adding new developers to the project:

1. Share this `CREDENTIALS.md` document
2. Share `.env.example` (already in Git)
3. **DO NOT** share your actual `.env` file
4. Each developer must:
   - Use the same Anon Key (safe to share via secure channel)
   - Use the same Service Role Key (share via 1Password/LastPass)
   - Generate their own Personal Access Token (never share tokens)

## Credential Rotation

### When to Rotate

Rotate credentials immediately if:
- Credentials are accidentally committed to Git
- A team member leaves the project
- Credentials are exposed in logs/screenshots
- Suspected unauthorized access
- Regular rotation schedule (every 90 days recommended)

### Rotation Procedure

#### Anon Key & Service Role Key
1. Navigate to: https://supabase.com/dashboard/project/jhnxscorszeslkhnxtif/settings/api
2. Click "Generate new anon key" or "Regenerate service role key"
3. Update `.env` with new keys
4. Notify all team members to update their local `.env`
5. Update Flutter app and redeploy if anon key changed
6. Old keys become invalid immediately after rotation

#### Personal Access Token
1. Navigate to: https://supabase.com/dashboard/account/tokens
2. Revoke old token
3. Generate new token with same scopes
4. Update `.env` with new token
5. Update CI/CD pipelines if token is used there

## Security Best Practices

### Pre-Commit Checklist
Before every commit:
```bash
# Verify .env is not staged
git status
# Should NOT show .env in "Changes to be committed"

# Double-check with:
git diff --cached --name-only | grep -E "\.env$"
# Should return empty (no output)
```

### If Credentials Leak

**Immediate Actions** (complete within 5 minutes):
1. Rotate all exposed credentials immediately (see Rotation Procedure above)
2. If committed to Git:
   ```bash
   # DO NOT use git commit --amend or rebase
   # If pushed to remote, keys are already compromised
   ```
3. Check Supabase logs for unauthorized access:
   - https://supabase.com/dashboard/project/jhnxscorszeslkhnxtif/logs/explorer
4. Report incident to project lead
5. Document in security incident log

**Within 24 hours**:
1. Review all database activity logs
2. Audit RLS policies for potential data exposure
3. Notify affected users if data breach occurred (GDPR requirement)

### Environment-Specific Configuration

For production deployment (future):
1. Create separate `.env.production` (also git-ignored)
2. Use separate Supabase project for production
3. Use CI/CD environment variables (GitHub Secrets, Vercel env vars)
4. Never use development credentials in production
5. Enable Supabase's "Restrict to Production" mode

## Verification Script

After setup, verify configuration:
```bash
bash scripts/verify_supabase_config.sh
```

This script checks:
- `.env` exists and is git-ignored
- All required environment variables are set
- Supabase project is accessible
- Auth configuration matches requirements (magic link expiration, email provider enabled)

## Troubleshooting

### "JWT failed verification" error
- **Cause**: Using wrong credential type for the API
- **Solution**: Management API requires Personal Access Token, not Service Role Key

### ".env file not found" error
- **Cause**: `.env` not created from template
- **Solution**: Run `cp .env.example .env` and fill with credentials

### "Invalid API key" error
- **Cause**: Anon/Service key is incorrect or expired
- **Solution**: Regenerate keys in Supabase dashboard, update `.env`

### Git shows .env as untracked file
- **Expected**: Git should ignore `.env` completely (won't show in `git status`)
- **If showing**: Verify `.gitignore` contains `.env` entry
- **Fix**: Run `git rm --cached .env` if accidentally added

## Configuration Values

### Magic Link Settings (Set via Management API)
```bash
# Magic link expiration: 15 minutes (900 seconds)
MAILER_OTP_EXP=900

# Session refresh token: 30 days (2,592,000 seconds)
# NOTE: Managed through Supabase Dashboard → Authentication → Settings
# Management API does not expose this setting directly
REFRESH_TOKEN_EXPIRY=2592000
```

### Manual Dashboard Configuration Required

The following settings must be configured manually in the Supabase Dashboard:

1. **Refresh Token Expiration** (30 days):
   - Navigate to: Authentication → Settings → Session Settings
   - Set "Refresh token time to live" to `2592000` seconds

2. **Email Provider** (already enabled ✓):
   - Navigate to: Authentication → Providers
   - Email provider: Enabled
   - Confirm email: OFF (magic links confirm email automatically)
   - Secure email change: ON

3. **Site URL** (for deep linking):
   - Navigate to: Authentication → URL Configuration
   - Site URL: `https://nova.galileimoro.edu.it`
   - Redirect URLs: Add `https://nova.galileimoro.edu.it/auth/confirm`

## Current Configuration Status

✅ **Completed via Management API**:
- `mailer_otp_exp`: 900 seconds (15 minutes)
- `external_email_enabled`: true
- `refresh_token_rotation_enabled`: true

⏳ **Requires Manual Dashboard Configuration**:
- Refresh token expiration: 2,592,000 seconds (30 days)
- Site URL: `https://nova.galileimoro.edu.it`
- Redirect URLs whitelist

🔄 **To be completed during implementation**:
- Auth Hooks for email domain validation
- Database schema deployment (PostgreSQL functions, triggers, RLS policies)
- Deep linking configuration (Android App Links, iOS Universal Links)
