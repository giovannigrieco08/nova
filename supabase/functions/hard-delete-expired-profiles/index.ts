// =====================================================================
// Nova - Hard Delete Expired Profiles Edge Function
// =====================================================================
// Purpose: Permanently delete profiles after 30-day grace period (GDPR Article 17)
// Schedule: Run via cron job (daily at 03:00 UTC)
// Trigger: POST request with service role authentication
// =====================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =====================================================================
// Type Definitions
// =====================================================================

interface ExpiredProfile {
  user_id: string
  deleted_at: string
  full_name: string | null
  avatar_url: string | null
}

interface DeletionResult {
  user_id: string
  status: 'deleted' | 'error'
  error?: string
}

// =====================================================================
// Main Handler
// =====================================================================

Deno.serve(async (req) => {
  const startTime = Date.now()

  try {
    // ---------------------------------------------------------------
    // 1. Verify HTTP Method & Authorization
    // ---------------------------------------------------------------
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // This function should only be called by cron job with service role
    const authHeader = req.headers.get('Authorization')
    const expectedKey = Deno.env.get('CRON_SECRET')

    // Allow service role OR cron secret
    const isServiceRole = authHeader?.includes(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '')
    const isCronJob = req.headers.get('X-Cron-Secret') === expectedKey

    if (!isServiceRole && !isCronJob) {
      console.error('❌ Unauthorized access attempt')
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log('🗑️  Starting hard delete job for expired profiles...')

    // ---------------------------------------------------------------
    // 2. Initialize Supabase Client (Service Role)
    // ---------------------------------------------------------------
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // ---------------------------------------------------------------
    // 3. Find Profiles Past 30-Day Grace Period
    // ---------------------------------------------------------------
    const thirtyDaysAgo = new Date()
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

    const { data: expiredProfiles, error: fetchError } = await supabase
      .from('profiles')
      .select('user_id, deleted_at, full_name, avatar_url')
      .not('deleted_at', 'is', null)
      .lt('deleted_at', thirtyDaysAgo.toISOString())

    if (fetchError) {
      console.error('❌ Error fetching expired profiles:', fetchError)
      throw new Error(`Failed to fetch expired profiles: ${fetchError.message}`)
    }

    if (!expiredProfiles || expiredProfiles.length === 0) {
      console.log('✅ No profiles to delete')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No profiles expired',
          deleted_count: 0,
          processing_time_ms: Date.now() - startTime
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📋 Found ${expiredProfiles.length} profiles to permanently delete`)

    // ---------------------------------------------------------------
    // 4. Process Each Profile
    // ---------------------------------------------------------------
    const results: DeletionResult[] = []

    for (const profile of expiredProfiles as ExpiredProfile[]) {
      try {
        console.log(`🔄 Processing user: ${profile.user_id}`)

        // 4a. Delete avatar from Storage (if exists)
        if (profile.avatar_url) {
          const avatarPath = extractStoragePath(profile.avatar_url)
          if (avatarPath) {
            const { error: storageError } = await supabase.storage
              .from('avatars')
              .remove([avatarPath])

            if (storageError) {
              console.warn(`⚠️ Failed to delete avatar for ${profile.user_id}:`, storageError)
              // Continue anyway - avatar deletion is not critical
            }
          }
        }

        // 4b. Delete GDPR export files (if any)
        const { data: exportFiles } = await supabase.storage
          .from('private')
          .list(`gdpr-exports/${profile.user_id}`)

        if (exportFiles && exportFiles.length > 0) {
          const filePaths = exportFiles.map(f => `gdpr-exports/${profile.user_id}/${f.name}`)
          await supabase.storage.from('private').remove(filePaths)
        }

        // 4c. Anonymize events created by user (don't delete - preserve content)
        await supabase
          .from('events')
          .update({ creator_id: null, creator_name_snapshot: 'Utente eliminato' })
          .eq('creator_id', profile.user_id)

        // 4d. Anonymize comments
        await supabase
          .from('comments')
          .update({ author_id: null, author_name_snapshot: 'Utente eliminato' })
          .eq('author_id', profile.user_id)

        // 4e. Delete chat messages (already soft-deleted, now hard delete)
        await supabase
          .from('chat_messages')
          .delete()
          .eq('sender_id', profile.user_id)

        // 4f. Delete event participations
        await supabase
          .from('event_participants')
          .delete()
          .eq('user_id', profile.user_id)

        // 4g. Delete notification preferences
        await supabase
          .from('notification_preferences')
          .delete()
          .eq('user_id', profile.user_id)

        // 4h. Delete FCM tokens
        await supabase
          .from('fcm_tokens')
          .delete()
          .eq('user_id', profile.user_id)

        // 4i. Delete the profile itself
        const { error: profileDeleteError } = await supabase
          .from('profiles')
          .delete()
          .eq('user_id', profile.user_id)

        if (profileDeleteError) {
          throw new Error(`Profile delete failed: ${profileDeleteError.message}`)
        }

        // 4j. Delete auth user (requires admin API)
        const { error: authDeleteError } = await supabase.auth.admin.deleteUser(
          profile.user_id
        )

        if (authDeleteError) {
          console.warn(`⚠️ Auth user delete failed for ${profile.user_id}:`, authDeleteError)
          // Profile is already deleted, log warning but consider success
        }

        console.log(`✅ Successfully deleted user: ${profile.user_id}`)
        results.push({ user_id: profile.user_id, status: 'deleted' })

      } catch (error) {
        console.error(`❌ Error deleting user ${profile.user_id}:`, error)
        results.push({
          user_id: profile.user_id,
          status: 'error',
          error: error instanceof Error ? error.message : 'Unknown error'
        })
      }
    }

    // ---------------------------------------------------------------
    // 5. Log Results to audit_logs Table
    // ---------------------------------------------------------------
    const successCount = results.filter(r => r.status === 'deleted').length
    const errorCount = results.filter(r => r.status === 'error').length

    await supabase.from('audit_logs').insert({
      action: 'gdpr_hard_delete_batch',
      actor_type: 'system',
      metadata: {
        total_processed: results.length,
        successful_deletions: successCount,
        failed_deletions: errorCount,
        processing_time_ms: Date.now() - startTime
      }
    })

    // ---------------------------------------------------------------
    // 6. Return Results
    // ---------------------------------------------------------------
    const totalTime = Date.now() - startTime
    console.log(`✅ Hard delete job completed in ${totalTime}ms`)
    console.log(`   Deleted: ${successCount}, Errors: ${errorCount}`)

    return new Response(
      JSON.stringify({
        success: true,
        deleted_count: successCount,
        error_count: errorCount,
        results: results,
        processing_time_ms: totalTime
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Hard delete job failed:', error)
    return new Response(
      JSON.stringify({
        error: 'Hard delete job failed',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

// =====================================================================
// Utility Functions
// =====================================================================

/**
 * Extract storage path from full URL
 */
function extractStoragePath(url: string): string | null {
  try {
    const urlObj = new URL(url)
    const pathParts = urlObj.pathname.split('/storage/v1/object/public/avatars/')
    if (pathParts.length > 1) {
      return pathParts[1]
    }
    // Try signed URL format
    const signedParts = urlObj.pathname.split('/storage/v1/object/sign/avatars/')
    if (signedParts.length > 1) {
      return signedParts[1].split('?')[0]
    }
    return null
  } catch {
    return null
  }
}

// =====================================================================
// Deployment & Scheduling
// =====================================================================
//
// 1. Deploy: npx supabase functions deploy hard-delete-expired-profiles
//
// 2. Set CRON_SECRET in Supabase Dashboard:
//    Settings → Edge Functions → Secrets
//
// 3. Create cron job in Supabase Dashboard (Database → Extensions → pg_cron):
//    SELECT cron.schedule(
//      'hard-delete-expired-profiles',
//      '0 3 * * *',  -- Daily at 03:00 UTC
//      $$
//      SELECT net.http_post(
//        url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/hard-delete-expired-profiles',
//        headers := jsonb_build_object(
//          'Content-Type', 'application/json',
//          'X-Cron-Secret', 'YOUR_CRON_SECRET'
//        ),
//        body := '{}'
//      );
//      $$
//    );
// =====================================================================
