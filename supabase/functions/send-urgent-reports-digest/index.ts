// Edge Function: send-urgent-reports-digest
// UGC Safety System - T062
// Purpose: Send digest email to moderators about urgent/pending reports
// Schedule: Every 4 hours via Supabase cron

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ReportDigest {
  total_pending: number;
  urgent_count: number;
  by_category: Record<string, number>;
  oldest_report_hours: number;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role for admin access
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get pending reports summary
    const { data: reports, error: reportsError } = await supabase
      .from("reports")
      .select("id, category, severity, created_at")
      .eq("status", "pending")
      .order("created_at", { ascending: true });

    if (reportsError) {
      throw new Error(`Failed to fetch reports: ${reportsError.message}`);
    }

    if (!reports || reports.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending reports", sent: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate digest stats
    const now = new Date();
    const oldestReport = reports[0];
    const oldestHours = Math.floor(
      (now.getTime() - new Date(oldestReport.created_at).getTime()) / (1000 * 60 * 60)
    );

    const byCategory: Record<string, number> = {};
    let urgentCount = 0;

    for (const report of reports) {
      byCategory[report.category] = (byCategory[report.category] || 0) + 1;
      if (report.severity === "high" || report.severity === "critical") {
        urgentCount++;
      }
    }

    const digest: ReportDigest = {
      total_pending: reports.length,
      urgent_count: urgentCount,
      by_category: byCategory,
      oldest_report_hours: oldestHours,
    };

    // Get moderator emails
    const { data: moderators, error: modError } = await supabase
      .from("profiles")
      .select("email")
      .eq("role", "moderator");

    if (modError || !moderators || moderators.length === 0) {
      console.log("No moderators found or error:", modError?.message);
      return new Response(
        JSON.stringify({ message: "No moderators to notify", digest }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build email content
    const subject = urgentCount > 0
      ? `[URGENTE] ${urgentCount} segnalazioni urgenti in attesa - Nova`
      : `${reports.length} segnalazioni in attesa di revisione - Nova`;

    const categoryList = Object.entries(byCategory)
      .map(([cat, count]) => `  - ${cat}: ${count}`)
      .join("\n");

    const body = `
Riepilogo Segnalazioni Nova
===========================

Segnalazioni in attesa: ${reports.length}
Segnalazioni urgenti: ${urgentCount}
Segnalazione più vecchia: ${oldestHours} ore fa

Per categoria:
${categoryList}

---
Accedi al pannello moderazione per gestire le segnalazioni.
`;

    // Log the digest (in production, this would send emails via SendGrid/Resend)
    console.log("=== MODERATION DIGEST ===");
    console.log("Subject:", subject);
    console.log("Body:", body);
    console.log("Moderators:", moderators.map((m) => m.email).join(", "));
    console.log("=========================");

    // TODO: Integrate with email provider (SendGrid, Resend, etc.)
    // For now, we just log and record the digest

    // Record digest was sent
    await supabase.from("moderation_digests").insert({
      total_pending: digest.total_pending,
      urgent_count: digest.urgent_count,
      by_category: digest.by_category,
      oldest_report_hours: digest.oldest_report_hours,
      sent_to: moderators.map((m) => m.email),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Digest processed",
        digest,
        moderators_notified: moderators.length,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in send-urgent-reports-digest:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
