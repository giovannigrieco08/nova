// =====================================================================
// Nova - Push Notification Edge Function (FCM v1 API)
// =====================================================================
// Purpose: Send FCM push notifications when in-app notifications are created
// Triggered by: Database Webhook on notifications table (INSERT)
// Architecture: notifications INSERT → Webhook → This Function → FCM v1 API → Device
// =====================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =====================================================================
// Type Definitions
// =====================================================================

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: NotificationRecord
  old_record?: NotificationRecord
  schema: string
}

interface NotificationRecord {
  id: string
  recipient_id: string
  sender_id: string | null
  type: string
  title: string
  description: string
  target_type: 'event' | 'comment'
  target_id: string
  metadata: Record<string, unknown>
  is_read: boolean
  created_at: string
}

interface FcmToken {
  id: string
  user_id: string
  token: string
  platform: 'android' | 'ios'
  device_name: string | null
}

interface ServiceAccount {
  type: string
  project_id: string
  private_key_id: string
  private_key: string
  client_email: string
  client_id: string
  auth_uri: string
  token_uri: string
}

interface SendResult {
  token: string
  success: boolean
  error?: string
}

// =====================================================================
// Constants
// =====================================================================

// Rate limiting: max 1 push per notification type per event per hour
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000 // 1 hour

// Stale token cleanup: remove tokens not used in 30 days
const STALE_TOKEN_DAYS = 30

// =====================================================================
// JWT & OAuth2 Helper Functions
// =====================================================================

/**
 * Create a JWT for FCM v1 API authentication
 */
async function createJwt(serviceAccount: ServiceAccount): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://fcm.googleapis.com/',
    iat: now,
    exp: now + 3600, // 1 hour expiry
  }

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedPayload = base64UrlEncode(JSON.stringify(payload))
  const signatureInput = `${encodedHeader}.${encodedPayload}`

  // Sign with private key
  const signature = await signWithPrivateKey(signatureInput, serviceAccount.private_key)

  return `${signatureInput}.${signature}`
}

/**
 * Base64 URL encode (no padding, URL-safe characters)
 */
function base64UrlEncode(str: string): string {
  const base64 = btoa(str)
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/**
 * Sign data with RSA private key (RS256)
 */
async function signWithPrivateKey(data: string, privateKeyPem: string): Promise<string> {
  // Parse PEM private key
  const pemContents = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '')

  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  // Import the key
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Sign the data
  const encoder = new TextEncoder()
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(data)
  )

  // Convert to base64url
  const signatureArray = new Uint8Array(signature)
  const base64Signature = btoa(String.fromCharCode(...signatureArray))
  return base64Signature.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/**
 * Get OAuth2 access token using service account JWT
 */
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const jwt = await createJwt(serviceAccount)

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Failed to get access token: ${error}`)
  }

  const data = await response.json()
  return data.access_token
}

// =====================================================================
// Main Handler
// =====================================================================

Deno.serve(async (req) => {
  const startTime = Date.now()

  try {
    // ---------------------------------------------------------------
    // 1. Verify HTTP Method
    // ---------------------------------------------------------------
    if (req.method !== 'POST') {
      console.error('Invalid HTTP method:', req.method)
      return new Response(
        JSON.stringify({ error: 'Method not allowed', allowed: 'POST' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // ---------------------------------------------------------------
    // 2. Parse Webhook Payload
    // ---------------------------------------------------------------
    const payload: WebhookPayload = await req.json()

    console.log('📥 Webhook received:', {
      type: payload.type,
      table: payload.table,
      notification_id: payload.record?.id,
      recipient_id: payload.record?.recipient_id,
      notification_type: payload.record?.type
    })

    // Only process INSERT events
    if (payload.type !== 'INSERT') {
      console.log('ℹ️ Ignoring non-INSERT event:', payload.type)
      return new Response(
        JSON.stringify({ success: true, message: 'Non-INSERT event ignored' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const notification = payload.record

    // ---------------------------------------------------------------
    // 3. Initialize Supabase Client & Get Service Account
    // ---------------------------------------------------------------
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing Supabase environment variables')
      throw new Error('Server configuration error: Missing Supabase credentials')
    }

    if (!serviceAccountJson) {
      console.error('Missing FIREBASE_SERVICE_ACCOUNT environment variable')
      throw new Error('Server configuration error: Missing Firebase credentials')
    }

    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    // ---------------------------------------------------------------
    // 4. Check User's push_enabled Flag
    // ---------------------------------------------------------------
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('user_id, push_enabled')
      .eq('user_id', notification.recipient_id)
      .single()

    if (profileError) {
      console.error('Error fetching user profile:', profileError)
      throw new Error(`Failed to fetch profile: ${profileError.message}`)
    }

    if (!profile?.push_enabled) {
      console.log('🔕 Push disabled for user:', notification.recipient_id)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Push notifications disabled for user',
          results: {
            tokens_found: 0,
            sent: 0,
            failed: 0,
            skipped_reason: 'push_disabled'
          }
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // ---------------------------------------------------------------
    // 4.5 Rate Limiting Check
    // ---------------------------------------------------------------
    const rateLimitKey = `${notification.recipient_id}:${notification.type}:${notification.target_id}`
    const oneHourAgo = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString()

    const { data: recentPush, error: rateLimitError } = await supabase
      .from('push_rate_limits')
      .select('id, sent_at')
      .eq('user_id', notification.recipient_id)
      .eq('notification_type', notification.type)
      .eq('target_id', notification.target_id)
      .gte('sent_at', oneHourAgo)
      .limit(1)
      .maybeSingle()

    if (rateLimitError) {
      console.warn('⚠️ Rate limit check failed:', rateLimitError.message)
    } else if (recentPush) {
      console.log('🚫 Rate limited:', {
        key: rateLimitKey,
        last_sent: recentPush.sent_at,
        notification_type: notification.type
      })
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Rate limited - similar notification sent recently',
          results: {
            tokens_found: 0,
            sent: 0,
            failed: 0,
            skipped_reason: 'rate_limited',
            rate_limit_key: rateLimitKey
          }
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // ---------------------------------------------------------------
    // 5. Get FCM Tokens for Recipient
    // ---------------------------------------------------------------
    const { data: tokens, error: tokensError } = await supabase
      .from('fcm_tokens')
      .select('id, user_id, token, platform, device_name')
      .eq('user_id', notification.recipient_id)

    if (tokensError) {
      console.error('Error fetching FCM tokens:', tokensError)
      throw new Error(`Failed to fetch tokens: ${tokensError.message}`)
    }

    if (!tokens || tokens.length === 0) {
      console.log('📱 No FCM tokens found for user:', notification.recipient_id)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No FCM tokens found for user',
          results: {
            tokens_found: 0,
            sent: 0,
            failed: 0
          }
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Found ${tokens.length} FCM token(s) for user:`, notification.recipient_id)

    // ---------------------------------------------------------------
    // 6. Get Unread Count for Badge
    // ---------------------------------------------------------------
    const { count: unreadCount } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('recipient_id', notification.recipient_id)
      .eq('is_read', false)

    const badgeCount = unreadCount ?? 1
    console.log('🔢 Badge count:', badgeCount)

    // ---------------------------------------------------------------
    // 7. Get OAuth2 Access Token
    // ---------------------------------------------------------------
    console.log('🔑 Getting OAuth2 access token...')
    const accessToken = await getAccessToken(serviceAccount)

    // ---------------------------------------------------------------
    // 8. Send Push to Each Token (FCM v1 API)
    // ---------------------------------------------------------------
    const sendResults: SendResult[] = []
    const invalidTokens: string[] = []

    for (const fcmToken of tokens as FcmToken[]) {
      const result = await sendFcmV1Push(
        fcmEndpoint,
        accessToken,
        fcmToken.token,
        fcmToken.platform,
        notification,
        badgeCount
      )

      sendResults.push(result)

      // Track invalid tokens for cleanup
      if (!result.success && isInvalidTokenError(result.error)) {
        invalidTokens.push(fcmToken.token)
        console.log('🗑️ Marking token for cleanup:', fcmToken.token.substring(0, 20) + '...')
      }
    }

    // ---------------------------------------------------------------
    // 9. Cleanup Invalid Tokens
    // ---------------------------------------------------------------
    if (invalidTokens.length > 0) {
      const { error: deleteError } = await supabase
        .from('fcm_tokens')
        .delete()
        .in('token', invalidTokens)

      if (deleteError) {
        console.error('Error cleaning up invalid tokens:', deleteError)
      } else {
        console.log(`🗑️ Cleaned up ${invalidTokens.length} invalid token(s)`)
      }
    }

    // ---------------------------------------------------------------
    // 10. Update last_used_at for Successful Tokens
    // ---------------------------------------------------------------
    const successfulTokens = sendResults
      .filter(r => r.success)
      .map(r => r.token)

    if (successfulTokens.length > 0) {
      const { error: updateError } = await supabase
        .from('fcm_tokens')
        .update({ last_used_at: new Date().toISOString() })
        .in('token', successfulTokens)

      if (updateError) {
        console.error('Error updating last_used_at:', updateError)
      }
    }

    // ---------------------------------------------------------------
    // 11. Record Rate Limit Entry
    // ---------------------------------------------------------------
    if (successfulTokens.length > 0) {
      const { error: rateLimitInsertError } = await supabase
        .from('push_rate_limits')
        .upsert({
          user_id: notification.recipient_id,
          notification_type: notification.type,
          target_id: notification.target_id,
          sent_at: new Date().toISOString()
        }, {
          onConflict: 'user_id,notification_type,target_id'
        })

      if (rateLimitInsertError) {
        console.warn('⚠️ Failed to record rate limit:', rateLimitInsertError.message)
      } else {
        console.log('📝 Rate limit recorded for:', rateLimitKey)
      }
    }

    // ---------------------------------------------------------------
    // 12. Stale Token Cleanup (10% probability)
    // ---------------------------------------------------------------
    if (Math.random() < 0.1) {
      await cleanupStaleTokens(supabase)
    }

    // ---------------------------------------------------------------
    // 13. Log and Return Results
    // ---------------------------------------------------------------
    const successCount = sendResults.filter(r => r.success).length
    const failureCount = sendResults.filter(r => !r.success).length
    const duration = Date.now() - startTime

    console.log('✅ Push notification send complete:', {
      notification_id: notification.id,
      recipient_id: notification.recipient_id,
      tokens_found: tokens.length,
      sent: successCount,
      failed: failureCount,
      invalid_tokens_cleaned: invalidTokens.length,
      duration_ms: duration
    })

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Push notifications sent',
        results: {
          tokens_found: tokens.length,
          sent: successCount,
          failed: failureCount,
          invalid_tokens_cleaned: invalidTokens.length,
          duration_ms: duration
        }
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    const duration = Date.now() - startTime

    console.error('❌ Edge Function error:', error)

    if (error instanceof Error) {
      console.error('   Error name:', error.name)
      console.error('   Error message:', error.message)
    }

    return new Response(
      JSON.stringify({
        error: 'Failed to send push notification',
        message: error instanceof Error ? error.message : 'Unknown error',
        duration_ms: duration,
        timestamp: new Date().toISOString()
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

// =====================================================================
// Helper: Send FCM v1 Push
// =====================================================================

async function sendFcmV1Push(
  endpoint: string,
  accessToken: string,
  token: string,
  platform: 'android' | 'ios',
  notification: NotificationRecord,
  badgeCount: number
): Promise<SendResult> {
  try {
    const fcmPayload = buildFcmV1Payload(token, platform, notification, badgeCount)

    console.log('📤 Sending FCM v1 to:', {
      token: token.substring(0, 20) + '...',
      platform,
      title: notification.title
    })

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(fcmPayload)
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      const errorMessage = errorData.error?.message || `HTTP ${response.status}`
      console.error('FCM v1 API error:', response.status, errorMessage)
      return {
        token,
        success: false,
        error: errorMessage
      }
    }

    const result = await response.json()
    console.log('✅ FCM v1 sent successfully:', result.name)
    return { token, success: true }

  } catch (error) {
    console.error('FCM v1 send error:', error)
    return {
      token,
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
  }
}

// =====================================================================
// Helper: Build FCM v1 Payload
// =====================================================================

function buildFcmV1Payload(
  token: string,
  platform: 'android' | 'ios',
  notification: NotificationRecord,
  badgeCount: number
): Record<string, unknown> {
  // Build deep link URL
  let deepLink: string
  if (notification.target_type === 'comment') {
    const eventId = notification.metadata?.event_id
    if (eventId) {
      deepLink = `nova://events/${eventId}/comments/${notification.target_id}`
    } else {
      console.warn('⚠️ Comment notification missing event_id in metadata')
      deepLink = 'nova://notifications'
    }
  } else {
    deepLink = `nova://events/${notification.target_id}`
  }

  // FCM v1 payload structure
  const payload: Record<string, unknown> = {
    message: {
      token: token,
      notification: {
        title: notification.title,
        body: notification.description,
      },
      data: {
        target_type: notification.target_type,
        target_id: notification.target_id,
        notification_id: notification.id,
        badge_count: badgeCount.toString(),
        deep_link: deepLink,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    }
  }

  // Platform-specific configuration
  if (platform === 'ios') {
    (payload.message as Record<string, unknown>).apns = {
      payload: {
        aps: {
          badge: badgeCount,
          sound: 'default',
          'mutable-content': 1,
          'content-available': 1
        }
      }
    }
  } else {
    // Android
    (payload.message as Record<string, unknown>).android = {
      priority: 'high',
      notification: {
        channel_id: 'nova_notifications',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        sound: 'default'
      }
    }
  }

  // Add event_id to data if target is a comment
  if (notification.target_type === 'comment' && notification.metadata?.event_id) {
    ((payload.message as Record<string, unknown>).data as Record<string, unknown>).event_id =
      notification.metadata.event_id as string
  }

  return payload
}

// =====================================================================
// Helper: Check if Error is Invalid Token
// =====================================================================

function isInvalidTokenError(error?: string): boolean {
  if (!error) return false

  const invalidTokenErrors = [
    'UNREGISTERED',
    'INVALID_ARGUMENT',
    'registration-token-not-registered',
    'invalid-registration-token',
    'NotRegistered',
    'InvalidRegistration'
  ]

  return invalidTokenErrors.some(e =>
    error.toLowerCase().includes(e.toLowerCase())
  )
}

// =====================================================================
// Helper: Cleanup Stale Tokens
// =====================================================================

async function cleanupStaleTokens(supabase: ReturnType<typeof createClient>): Promise<void> {
  try {
    const staleDate = new Date()
    staleDate.setDate(staleDate.getDate() - STALE_TOKEN_DAYS)
    const staleDateIso = staleDate.toISOString()

    console.log('🧹 Running stale token cleanup (tokens older than:', staleDateIso, ')')

    const { data: staleTokens, error: queryError } = await supabase
      .from('fcm_tokens')
      .select('id, token, last_used_at, created_at')
      .or(`last_used_at.lt.${staleDateIso},and(last_used_at.is.null,created_at.lt.${staleDateIso})`)
      .limit(100)

    if (queryError) {
      console.error('Error querying stale tokens:', queryError)
      return
    }

    if (!staleTokens || staleTokens.length === 0) {
      console.log('✅ No stale tokens found')
      return
    }

    const tokenIds = staleTokens.map(t => t.id)

    const { error: deleteError } = await supabase
      .from('fcm_tokens')
      .delete()
      .in('id', tokenIds)

    if (deleteError) {
      console.error('Error deleting stale tokens:', deleteError)
    } else {
      console.log(`🗑️ Cleaned up ${staleTokens.length} stale token(s)`)
    }

    // Cleanup old rate limit records
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()

    const { error: rateLimitCleanupError } = await supabase
      .from('push_rate_limits')
      .delete()
      .lt('sent_at', oneDayAgo)

    if (rateLimitCleanupError) {
      console.warn('⚠️ Error cleaning up old rate limits:', rateLimitCleanupError.message)
    } else {
      console.log('🧹 Cleaned up old rate limit records')
    }

  } catch (error) {
    console.error('Error in stale token cleanup:', error)
  }
}

// =====================================================================
// Edge Function ready for FCM v1 API!
// =====================================================================
//
// Deployment steps:
// 1. Set Firebase service account:
//    npx supabase secrets set FIREBASE_SERVICE_ACCOUNT='<json-content>'
//
// 2. Deploy function:
//    npx supabase functions deploy send-push-notification
//
// 3. Configure webhook in Supabase Dashboard:
//    - Go to Database → Webhooks → Create new
//    - Table: notifications
//    - Events: INSERT
//    - Type: Supabase Edge Function
//    - Function: send-push-notification
//
// =====================================================================
