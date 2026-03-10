// =====================================================================
// Pending Reports Provider - Moderation Queue for Reports
// =====================================================================
// Purpose: Fetch pending reports for moderators to review
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/moderation_report.dart';

/// Provider for fetching pending reports with user information
final pendingReportsProvider =
    FutureProvider.autoDispose<List<ModerationReport>>((ref) async {
  final supabase = Supabase.instance.client;

  // Use the get_pending_reports RPC function
  final response = await supabase.rpc('get_pending_reports', params: {
    'p_limit': 100,
    'p_offset': 0,
  });

  final data = response as Map<String, dynamic>;
  final reportsJson = data['reports'] as List<dynamic>? ?? [];

  // Fetch additional user info for profile reports
  final reports = <ModerationReport>[];

  for (final json in reportsJson) {
    final reportJson = json as Map<String, dynamic>;
    final contentType = reportJson['content_type'] as String?;
    final contentId = reportJson['content_id'] as String?;

    String? reportedUserId;
    String? reportedUserName;
    String? reportedUserUsername;
    String? reportedUserAvatarUrl;

    // Get reported user info based on content type
    if (contentType == 'profile' && contentId != null) {
      reportedUserId = contentId;
      // Fetch profile info
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('full_name, username, avatar_url')
            .eq('user_id', contentId)
            .maybeSingle();

        if (profileResponse != null) {
          reportedUserName = profileResponse['full_name'] as String?;
          reportedUserUsername = profileResponse['username'] as String?;
          reportedUserAvatarUrl = profileResponse['avatar_url'] as String?;
        }
      } catch (_) {
        // Ignore profile fetch errors
      }
    } else if (contentType == 'event' && contentId != null) {
      // Get event creator
      try {
        final eventResponse = await supabase
            .from('events')
            .select('creator_id')
            .eq('id', contentId)
            .maybeSingle();

        if (eventResponse != null) {
          reportedUserId = eventResponse['creator_id'] as String?;
          if (reportedUserId != null) {
            final profileResponse = await supabase
                .from('profiles')
                .select('full_name, username, avatar_url')
                .eq('user_id', reportedUserId)
                .maybeSingle();

            if (profileResponse != null) {
              reportedUserName = profileResponse['full_name'] as String?;
              reportedUserUsername = profileResponse['username'] as String?;
              reportedUserAvatarUrl = profileResponse['avatar_url'] as String?;
            }
          }
        }
      } catch (_) {
        // Ignore errors
      }
    } else if (contentType == 'comment' && contentId != null) {
      // Get comment author
      try {
        final commentResponse = await supabase
            .from('comments')
            .select('user_id')
            .eq('id', contentId)
            .maybeSingle();

        if (commentResponse != null) {
          reportedUserId = commentResponse['user_id'] as String?;
          if (reportedUserId != null) {
            final profileResponse = await supabase
                .from('profiles')
                .select('full_name, username, avatar_url')
                .eq('user_id', reportedUserId)
                .maybeSingle();

            if (profileResponse != null) {
              reportedUserName = profileResponse['full_name'] as String?;
              reportedUserUsername = profileResponse['username'] as String?;
              reportedUserAvatarUrl = profileResponse['avatar_url'] as String?;
            }
          }
        }
      } catch (_) {
        // Ignore errors
      }
    }

    // Add info to JSON
    reportJson['reported_user_id'] = reportedUserId;
    reportJson['reported_user_name'] = reportedUserName;
    reportJson['reported_user_username'] = reportedUserUsername;
    reportJson['reported_user_avatar_url'] = reportedUserAvatarUrl;

    reports.add(ModerationReport.fromJson(reportJson));
  }

  return reports;
});

/// Provider for moderation stats
final moderationStatsProvider =
    FutureProvider.autoDispose<ModerationStats>((ref) async {
  final supabase = Supabase.instance.client;

  final response = await supabase.rpc('get_moderation_stats');
  final data = response as Map<String, dynamic>;

  return ModerationStats(
    pendingReports: data['pending_reports'] as int? ?? 0,
    urgentReports: data['urgent_reports'] as int? ?? 0,
    reportsToday: data['reports_today'] as int? ?? 0,
    reportsThisWeek: data['reports_this_week'] as int? ?? 0,
  );
});

/// Moderation statistics
class ModerationStats {
  const ModerationStats({
    required this.pendingReports,
    required this.urgentReports,
    required this.reportsToday,
    required this.reportsThisWeek,
  });

  final int pendingReports;
  final int urgentReports;
  final int reportsToday;
  final int reportsThisWeek;
}
