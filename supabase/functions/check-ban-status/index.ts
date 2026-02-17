// Edge Function: check-ban-status
// UGC Safety System - T063
// Purpose: Check if user is banned on sign-in and return appropriate error
// Integration: Called from Supabase Auth hook or client-side after auth

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface BanStatus {
  is_banned: boolean;
  ban_type?: "temporary" | "permanent";
  ban_reason?: string;
  ban_expires_at?: string;
  can_appeal: boolean;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get user ID from request body or JWT
    const { user_id } = await req.json().catch(() => ({}));

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // If no user_id provided, try to get from auth header
    let userId = user_id;
    if (!userId) {
      const authHeader = req.headers.get("Authorization");
      if (authHeader) {
        const token = authHeader.replace("Bearer ", "");
        const { data: { user }, error: authError } = await supabase.auth.getUser(token);
        if (authError || !user) {
          return new Response(
            JSON.stringify({ error: "Invalid or missing user authentication" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        userId = user.id;
      }
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: "user_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check for active sanctions
    const now = new Date().toISOString();
    const { data: sanctions, error: sanctionError } = await supabase
      .from("user_sanctions")
      .select("*")
      .eq("user_id", userId)
      .eq("is_active", true)
      .or(`expires_at.is.null,expires_at.gt.${now}`)
      .order("created_at", { ascending: false })
      .limit(1);

    if (sanctionError) {
      throw new Error(`Failed to check sanctions: ${sanctionError.message}`);
    }

    // No active sanctions
    if (!sanctions || sanctions.length === 0) {
      const status: BanStatus = {
        is_banned: false,
        can_appeal: false,
      };
      return new Response(
        JSON.stringify(status),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // User has active sanction
    const sanction = sanctions[0];
    const isPermanent = sanction.sanction_type === "ban" && !sanction.expires_at;
    const isTemporary = sanction.sanction_type === "ban" && sanction.expires_at;

    const status: BanStatus = {
      is_banned: sanction.sanction_type === "ban",
      ban_type: isPermanent ? "permanent" : isTemporary ? "temporary" : undefined,
      ban_reason: sanction.reason,
      ban_expires_at: sanction.expires_at,
      can_appeal: !isPermanent && !sanction.appeal_submitted,
    };

    // If banned, return 403
    if (status.is_banned) {
      const message = isPermanent
        ? "Il tuo account è stato sospeso permanentemente per violazione dei Termini di Servizio."
        : `Il tuo account è sospeso fino al ${new Date(sanction.expires_at).toLocaleDateString("it-IT")}. Motivo: ${sanction.reason}`;

      return new Response(
        JSON.stringify({
          ...status,
          message,
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Return warning status (e.g., user has warning but not banned)
    return new Response(
      JSON.stringify({
        ...status,
        warning: sanction.sanction_type === "warning",
        warning_reason: sanction.reason,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in check-ban-status:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
