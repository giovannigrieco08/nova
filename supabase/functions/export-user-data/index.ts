// Edge Function: export-user-data
// Feature: 006-user-profile (User Story 3 - T059)
// Purpose: GDPR Right to Access - export all user data as JSON

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

console.log('Edge Function: export-user-data started');

serve(async (req) => {
  try {
    // CORS headers (for preflight requests)
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      });
    }

    // Parse request body
    const { user_id } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'Missing user_id in request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Initialize Supabase client (server-side with service role key)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log(`Exporting data for user: ${user_id}`);

    // Start timer for performance tracking (target <10s per FR-049)
    const startTime = Date.now();

    // =========================================================================
    // QUERY 1: Fetch user profile
    // =========================================================================
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('user_id', user_id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'User not found or unauthorized' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // =========================================================================
    // QUERY 2: Fetch events created by user (all statuses)
    // =========================================================================
    const { data: eventsCreated, error: eventsError } = await supabase
      .from('events')
      .select('*')
      .eq('creator_id', user_id)
      .order('created_at', { ascending: false });

    if (eventsError) {
      console.error('Error fetching events:', eventsError);
    }

    // =========================================================================
    // QUERY 3: Fetch participations
    // =========================================================================
    const { data: participations, error: participationsError } = await supabase
      .from('participations')
      .select('*')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false });

    if (participationsError) {
      console.error('Error fetching participations:', participationsError);
    }

    // =========================================================================
    // QUERY 4: Fetch comments posted by user
    // =========================================================================
    const { data: comments, error: commentsError } = await supabase
      .from('comments')
      .select('*')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false });

    if (commentsError) {
      console.error('Error fetching comments:', commentsError);
    }

    // =========================================================================
    // QUERY 5: Fetch chat messages (last 24h only, auto-delete policy)
    // =========================================================================
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { data: chatMessages, error: chatError } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('sender_id', user_id)
      .gte('created_at', twentyFourHoursAgo)
      .order('created_at', { ascending: false });

    if (chatError) {
      console.error('Error fetching chat messages:', chatError);
    }

    // =========================================================================
    // BUILD GDPR EXPORT JSON
    // =========================================================================
    const exportData = {
      export_version: '1.0',
      export_date: new Date().toISOString(),
      user_id: user_id,
      profile: profile,
      events_created: eventsCreated || [],
      participations: participations || [],
      comments: comments || [],
      chat_messages: chatMessages || [],
    };

    // Convert to JSON string
    const jsonString = JSON.stringify(exportData, null, 2);
    const jsonBytes = new TextEncoder().encode(jsonString);
    const fileSizeBytes = jsonBytes.length;

    // =========================================================================
    // UPLOAD JSON TO STORAGE (bucket: gdpr-exports)
    // =========================================================================
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `${user_id}/${timestamp}.json`;

    const { error: uploadError } = await supabase.storage
      .from('gdpr-exports')
      .upload(fileName, jsonBytes, {
        contentType: 'application/json',
        upsert: false, // Don't overwrite existing exports
      });

    if (uploadError) {
      console.error('Error uploading export to storage:', uploadError);
      return new Response(
        JSON.stringify({ error: 'Failed to upload export to storage' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // =========================================================================
    // GENERATE SIGNED URL (24h expiry)
    // =========================================================================
    const { data: signedUrlData, error: signedUrlError } = await supabase.storage
      .from('gdpr-exports')
      .createSignedUrl(fileName, 86400); // 86400 seconds = 24 hours

    if (signedUrlError || !signedUrlData) {
      console.error('Error generating signed URL:', signedUrlError);
      return new Response(
        JSON.stringify({ error: 'Failed to generate download URL' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // =========================================================================
    // PERFORMANCE CHECK (target <10s per FR-049)
    // =========================================================================
    const elapsedTime = Date.now() - startTime;
    console.log(`Export completed in ${elapsedTime}ms (target: <10000ms)`);

    if (elapsedTime > 10000) {
      console.warn(`⚠️ Export took ${elapsedTime}ms, exceeds 10s target (FR-049)`);
    }

    // =========================================================================
    // RETURN METADATA TO CLIENT
    // =========================================================================
    const expiresAt = new Date(Date.now() + 86400 * 1000).toISOString(); // 24h from now

    const metadata = {
      export_id: timestamp,
      generated_at: new Date().toISOString(),
      download_url: signedUrlData.signedUrl,
      file_size_bytes: fileSizeBytes,
      expires_at: expiresAt,
    };

    return new Response(JSON.stringify(metadata), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
