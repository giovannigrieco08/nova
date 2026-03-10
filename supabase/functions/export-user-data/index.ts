// =====================================================================
// Nova - GDPR Data Export Edge Function
// =====================================================================
// Purpose: Export all user data in JSON format (GDPR Article 15)
// Architecture: Authenticated user request → Collect data → Generate JSON → Upload to Storage
// Response time target: <10 seconds
// =====================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =====================================================================
// Type Definitions
// =====================================================================

interface ExportData {
  export_metadata: {
    generated_at: string
    user_id: string
    gdpr_article: string
    format_version: string
  }
  profile: Record<string, any> | null
  events_created: Record<string, any>[]
  event_participations: Record<string, any>[]
  comments: Record<string, any>[]
  chat_messages_last_24h: Record<string, any>[]
  constellations: Record<string, any>[]
  notification_preferences: Record<string, any> | null
}

// =====================================================================
// Data Collection Functions
// =====================================================================

async function collectProfile(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('user_id', userId)
    .single()

  if (error && error.code !== 'PGRST116') {
    console.error('Error fetching profile:', error)
  }
  return data
}

async function collectEvents(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('events')
    .select('id, title, description, date, created_at, updated_at')
    .eq('creator_id', userId)
    .order('created_at', { ascending: false })

  if (error) console.error('Error fetching events:', error)
  return data || []
}

async function collectParticipations(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('event_participants')
    .select('event_id, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })

  if (error) console.error('Error fetching participations:', error)
  return data || []
}

async function collectComments(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('comments')
    .select('id, event_id, content, created_at')
    .eq('author_id', userId)
    .order('created_at', { ascending: false })

  if (error) console.error('Error fetching comments:', error)
  return data || []
}

async function collectChatMessages(supabase: SupabaseClient, userId: string) {
  // Only last 24 hours of chat messages for privacy
  const twentyFourHoursAgo = new Date()
  twentyFourHoursAgo.setHours(twentyFourHoursAgo.getHours() - 24)

  const { data, error } = await supabase
    .from('chat_messages')
    .select('id, content, created_at, room_type')
    .eq('sender_id', userId)
    .gte('created_at', twentyFourHoursAgo.toISOString())
    .order('created_at', { ascending: false })

  if (error) console.error('Error fetching chat messages:', error)
  return data || []
}

async function collectConstellations(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('constellations')
    .select('id, title, description, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })

  if (error) console.error('Error fetching constellations:', error)
  return data || []
}

async function collectNotificationPrefs(supabase: SupabaseClient, userId: string) {
  const { data, error } = await supabase
    .from('notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .single()

  if (error && error.code !== 'PGRST116') {
    console.error('Error fetching notification prefs:', error)
  }
  return data
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
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // ---------------------------------------------------------------
    // 2. Authenticate User
    // ---------------------------------------------------------------
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Create client with user's JWT to verify identity
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const userId = user.id
    console.log(`📦 Starting GDPR export for user: ${userId}`)

    // Use service role for data collection (bypasses RLS)
    const serviceClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // ---------------------------------------------------------------
    // 3. Collect All User Data (Parallel for performance)
    // ---------------------------------------------------------------
    const startTime = Date.now()

    const [
      profile,
      events,
      participations,
      comments,
      chatMessages,
      constellations,
      notificationPrefs
    ] = await Promise.all([
      collectProfile(serviceClient, userId),
      collectEvents(serviceClient, userId),
      collectParticipations(serviceClient, userId),
      collectComments(serviceClient, userId),
      collectChatMessages(serviceClient, userId),
      collectConstellations(serviceClient, userId),
      collectNotificationPrefs(serviceClient, userId)
    ])

    const collectTime = Date.now() - startTime
    console.log(`✅ Data collection completed in ${collectTime}ms`)

    // ---------------------------------------------------------------
    // 4. Build Export JSON
    // ---------------------------------------------------------------
    const exportData: ExportData = {
      export_metadata: {
        generated_at: new Date().toISOString(),
        user_id: userId,
        gdpr_article: 'Article 15 - Right of Access',
        format_version: '1.0.0'
      },
      profile: profile ? {
        ...profile,
        // Redact sensitive internal fields
        user_id: userId,
      } : null,
      events_created: events,
      event_participations: participations,
      comments: comments,
      chat_messages_last_24h: chatMessages,
      constellations: constellations,
      notification_preferences: notificationPrefs
    }

    const jsonContent = JSON.stringify(exportData, null, 2)
    const jsonBlob = new Blob([jsonContent], { type: 'application/json' })

    // ---------------------------------------------------------------
    // 5. Upload to Supabase Storage
    // ---------------------------------------------------------------
    const fileName = `gdpr-exports/${userId}/${Date.now()}-export.json`

    const { error: uploadError } = await serviceClient.storage
      .from('private')
      .upload(fileName, jsonBlob, {
        contentType: 'application/json',
        upsert: false
      })

    if (uploadError) {
      console.error('❌ Upload error:', uploadError)
      throw new Error(`Failed to upload export: ${uploadError.message}`)
    }

    // ---------------------------------------------------------------
    // 6. Generate Signed URL (expires in 24 hours)
    // ---------------------------------------------------------------
    const { data: signedUrlData, error: signedUrlError } = await serviceClient.storage
      .from('private')
      .createSignedUrl(fileName, 60 * 60 * 24) // 24 hours

    if (signedUrlError || !signedUrlData) {
      console.error('❌ Signed URL error:', signedUrlError)
      throw new Error('Failed to generate download URL')
    }

    const totalTime = Date.now() - startTime
    console.log(`✅ Export completed in ${totalTime}ms for user: ${userId}`)

    // ---------------------------------------------------------------
    // 7. Return Success Response
    // ---------------------------------------------------------------
    return new Response(
      JSON.stringify({
        success: true,
        download_url: signedUrlData.signedUrl,
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        file_size_bytes: jsonBlob.size,
        data_summary: {
          events_count: events.length,
          participations_count: participations.length,
          comments_count: comments.length,
          chat_messages_count: chatMessages.length,
          constellations_count: constellations.length
        },
        processing_time_ms: totalTime
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Export error:', error)
    return new Response(
      JSON.stringify({
        error: 'Failed to export user data',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
