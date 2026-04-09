import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/moderation_report.dart';

/// Report moderation statistics.
@immutable
class ReportStats {
  final int pendingReports;
  final int urgentReports;
  final int reportsToday;
  final int reportsThisWeek;

  const ReportStats({
    required this.pendingReports,
    required this.urgentReports,
    required this.reportsToday,
    required this.reportsThisWeek,
  });
}

/// Repository for moderation-related Supabase queries.
class ModerationRepository {
  final SupabaseClient _supabase;

  ModerationRepository(this._supabase);

  /// Fetch pending reports with enriched user info.
  Future<List<ModerationReport>> getPendingReports({
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _supabase.rpc('get_pending_reports', params: {
      'p_limit': limit,
      'p_offset': offset,
    });

    final data = response as Map<String, dynamic>;
    final reportsJson = data['reports'] as List<dynamic>? ?? [];

    final reports = <ModerationReport>[];

    for (final json in reportsJson) {
      final reportJson = json as Map<String, dynamic>;
      final contentType = reportJson['content_type'] as String?;
      final contentId = reportJson['content_id'] as String?;

      String? reportedUserId;
      String? reportedUserName;
      String? reportedUserUsername;
      String? reportedUserAvatarUrl;

      if (contentType == 'profile' && contentId != null) {
        reportedUserId = contentId;
        final profile = await _fetchProfile(contentId);
        if (profile != null) {
          reportedUserName = profile['full_name'] as String?;
          reportedUserUsername = profile['username'] as String?;
          reportedUserAvatarUrl = profile['avatar_url'] as String?;
        }
      } else if (contentType == 'event' && contentId != null) {
        reportedUserId = await _getEventCreatorId(contentId);
        if (reportedUserId != null) {
          final profile = await _fetchProfile(reportedUserId);
          if (profile != null) {
            reportedUserName = profile['full_name'] as String?;
            reportedUserUsername = profile['username'] as String?;
            reportedUserAvatarUrl = profile['avatar_url'] as String?;
          }
        }
      } else if (contentType == 'comment' && contentId != null) {
        reportedUserId = await _getCommentAuthorId(contentId);
        if (reportedUserId != null) {
          final profile = await _fetchProfile(reportedUserId);
          if (profile != null) {
            reportedUserName = profile['full_name'] as String?;
            reportedUserUsername = profile['username'] as String?;
            reportedUserAvatarUrl = profile['avatar_url'] as String?;
          }
        }
      }

      reportJson['reported_user_id'] = reportedUserId;
      reportJson['reported_user_name'] = reportedUserName;
      reportJson['reported_user_username'] = reportedUserUsername;
      reportJson['reported_user_avatar_url'] = reportedUserAvatarUrl;

      reports.add(ModerationReport.fromJson(reportJson));
    }

    return reports;
  }

  /// Fetch moderation stats.
  Future<ReportStats> getStats() async {
    final response = await _supabase.rpc('get_moderation_stats');
    final data = response as Map<String, dynamic>;

    return ReportStats(
      pendingReports: data['pending_reports'] as int? ?? 0,
      urgentReports: data['urgent_reports'] as int? ?? 0,
      reportsToday: data['reports_today'] as int? ?? 0,
      reportsThisWeek: data['reports_this_week'] as int? ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select('full_name, username, avatar_url')
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getEventCreatorId(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('creator_id')
          .eq('id', eventId)
          .maybeSingle();
      return response?['creator_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getCommentAuthorId(String commentId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', commentId)
          .maybeSingle();
      return response?['user_id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
