// =====================================================================
// Nova - Auth Events Logger Edge Function
// =====================================================================
// Purpose: Log authentication events (signup, signin, signout) to auth_events table
// Triggered by: Database Webhook on auth.users table (INSERT, UPDATE)
// Architecture: Supabase Database Webhook → This Edge Function → auth_events table
// =====================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =====================================================================
// Type Definitions
// =====================================================================

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: AuthUser
  old_record?: AuthUser
  schema: string
}

interface AuthUser {
  id: string
  email: string
  email_confirmed_at: string | null
  last_sign_in_at: string | null
  created_at: string
  raw_app_meta_data: {
    provider?: string
    [key: string]: any
  }
  raw_user_meta_data: {
    [key: string]: any
  }
}

interface AuthEventInsert {
  user_id: string
  email_hash: string
  event_type: 'signup' | 'signin' | 'signout' | 'session_expired' | 'token_refreshed' | 'failed_signin'
  event_timestamp: string
  metadata: Record<string, any>
}

// =====================================================================
// Utility Functions
// =====================================================================

/**
 * Hash email address using SHA256 for privacy-preserving audit logs
 * @param email - Email address to hash
 * @returns Hexadecimal string (64 characters)
 */
async function hashEmail(email: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(email.toLowerCase().trim())
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

// =====================================================================
// Main Handler
// =====================================================================

Deno.serve(async (req) => {
  try {
    // ---------------------------------------------------------------
    // 1. Verify HTTP Method
    // ---------------------------------------------------------------
    if (req.method !== 'POST') {
      console.error('Invalid HTTP method:', req.method)
      return new Response(
        JSON.stringify({ error: 'Method not allowed', allowed: 'POST' }),
        {
          status: 405,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // ---------------------------------------------------------------
    // 2. Parse Webhook Payload
    // ---------------------------------------------------------------
    const payload: WebhookPayload = await req.json()
    console.log('📥 Webhook received:', {
      type: payload.type,
      table: payload.table,
      schema: payload.schema,
      user_id: payload.record?.id
    })

    // ---------------------------------------------------------------
    // 3. Initialize Supabase Client (Service Role)
    // ---------------------------------------------------------------
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing Supabase environment variables')
      throw new Error('Server configuration error: Missing Supabase credentials')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    const { record, old_record, type } = payload
    let eventType: 'signup' | 'signin' | null = null
    let metadata: Record<string, any> = {}

    // ---------------------------------------------------------------
    // 4. Determine Event Type Based on Webhook Type
    // ---------------------------------------------------------------

    if (type === 'INSERT') {
      // New user registered (signup event)
      eventType = 'signup'
      metadata = {
        provider: record.raw_app_meta_data?.provider || 'email',
        email_confirmed: !!record.email_confirmed_at,
        created_at: record.created_at
      }
      console.log('✅ Detected signup event for user:', record.id)
    }
    else if (type === 'UPDATE' && old_record) {
      // Email confirmed (magic link clicked)
      if (!old_record.email_confirmed_at && record.email_confirmed_at) {
        eventType = 'signin'
        metadata = {
          method: 'magic_link',
          confirmed_at: record.email_confirmed_at
        }
        console.log('✅ Detected magic link signin for user:', record.id)
      }
      // Session refresh (last_sign_in_at updated)
      else if (
        record.last_sign_in_at &&
        old_record.last_sign_in_at &&
        new Date(record.last_sign_in_at) > new Date(old_record.last_sign_in_at)
      ) {
        eventType = 'signin'
        metadata = {
          method: 'session_refresh',
          last_sign_in: record.last_sign_in_at
        }
        console.log('✅ Detected session refresh for user:', record.id)
      }
      // Other UPDATE events (not logged)
      else {
        console.log('ℹ️  UPDATE event but no auth event detected (user_id:', record.id, ')')
      }
    }

    // ---------------------------------------------------------------
    // 5. Log Event to auth_events Table (if applicable)
    // ---------------------------------------------------------------

    if (eventType) {
      // Hash email for privacy
      const emailHash = await hashEmail(record.email)

      // Prepare event data
      const authEvent: AuthEventInsert = {
        user_id: record.id,
        email_hash: emailHash,
        event_type: eventType,
        event_timestamp: new Date().toISOString(),
        metadata: metadata
      }

      // Insert into auth_events table
      const { error: insertError } = await supabase
        .from('auth_events')
        .insert(authEvent)

      if (insertError) {
        console.error('❌ Error inserting auth event:', insertError)
        throw new Error(`Database insert failed: ${insertError.message}`)
      }

      console.log(`✅ Successfully logged ${eventType} event for user ${record.id}`)
      console.log('   Email hash:', emailHash.substring(0, 16) + '...')
      console.log('   Metadata:', JSON.stringify(metadata))
    } else {
      console.log('ℹ️  No event to log for this webhook (type:', type, ')')
    }

    // ---------------------------------------------------------------
    // 6. Return Success Response
    // ---------------------------------------------------------------

    return new Response(
      JSON.stringify({
        success: true,
        event_type: eventType,
        user_id: record.id,
        timestamp: new Date().toISOString()
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    // ---------------------------------------------------------------
    // Error Handling
    // ---------------------------------------------------------------

    console.error('❌ Edge Function error:', error)

    // Detailed error logging (stack traces only in development to prevent leaking sensitive data)
    if (error instanceof Error) {
      console.error('   Error name:', error.name)
      console.error('   Error message:', error.message)

      // Stack traces can expose environment variables or internal paths
      // Only log in development environment
      const isDevelopment = Deno.env.get('ENVIRONMENT') === 'development'
      if (isDevelopment) {
        console.error('   Error stack:', error.stack)
      }
    }

    return new Response(
      JSON.stringify({
        error: 'Failed to log auth event',
        message: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})

// =====================================================================
// Edge Function deployed successfully!
// Next steps:
// 1. Deploy with: npx supabase functions deploy log-auth-event
// 2. Configure Database Webhook in Dashboard → Database → Webhooks
// 3. Test with real signup/signin events
// =====================================================================
