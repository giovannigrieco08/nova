// =====================================================================
// AdminRepository - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Data access layer for admin operations
// Architecture: Repository pattern with Supabase RPC calls
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/providers/supabase_provider.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';
import 'package:nova/features/admin/domain/entities/activity_log_entry.dart';

/// Repository for admin operations
///
/// Handles searching users, promoting/removing moderators,
/// fetching moderator lists, and getting system statistics.
class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  /// Search users by name, email, or class
  ///
  /// Returns list of users matching the search query.
  /// Searches across full_name, email, and class_name fields.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, class_name')
          .or('full_name.ilike.%$query%,email.ilike.%$query%,class_name.ilike.%$query%')
          .order('full_name');

      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to search users: ${e.message}');
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Promote user to moderator
  ///
  /// Calls the `promote_to_moderator` database function which:
  /// - Creates user_roles entry with role='moderator'
  /// - Restores archived statistics if user was previously a moderator
  /// - Logs action to admin_log table
  /// - Creates notification for the promoted user
  Future<void> promoteToModerator(String userId) async {
    try {
      await _supabase.rpc('promote_to_moderator', params: {
        'p_user_id': userId,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to promote user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to promote user: $e');
    }
  }

  /// Remove moderator role
  ///
  /// Calls the `remove_moderator_role` database function which:
  /// - Deletes user_roles entry with role='moderator'
  /// - Archives current statistics to moderator_stats_archive
  /// - Logs action to admin_log table
  /// - Creates notification for the demoted user
  Future<void> removeModerator(String userId) async {
    try {
      await _supabase.rpc('remove_moderator_role', params: {
        'p_user_id': userId,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove moderator: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove moderator: $e');
    }
  }

  /// Get all moderators with statistics
  ///
  /// Returns list of moderators with their user info and performance stats.
  /// Joins user_roles, profiles, and moderator_stats tables.
  Future<List<Moderator>> getModerators() async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('''
            user_id,
            profiles!inner(full_name, email, class_name),
            moderator_stats(total_reviews, reviews_this_week, approval_rate_percent, last_review_at)
          ''')
          .eq('role', 'moderator')
          .order('profiles(full_name)');

      return (response as List).map((json) {
        final profile = json['profiles'] as Map<String, dynamic>;
        final stats = json['moderator_stats'] as Map<String, dynamic>?;

        return Moderator(
          userId: json['user_id'] as String,
          fullName: profile['full_name'] as String,
          email: profile['email'] as String,
          className: profile['class_name'] as String,
          totalReviews: stats?['total_reviews'] ?? 0,
          reviewsThisWeek: stats?['reviews_this_week'] ?? 0,
          approvalRatePercent: (stats?['approval_rate_percent'] ?? 0).toDouble(),
          lastReviewAt: stats?['last_review_at'] != null
              ? DateTime.parse(stats!['last_review_at'] as String)
              : null,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch moderators: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch moderators: $e');
    }
  }

  /// Get system statistics
  ///
  /// Calls the `get_system_statistics` database function which returns:
  /// - Event counts (total, pending, approved, rejected)
  /// - Moderator counts (total, active in last 7 days)
  /// - Average review time in hours
  /// - Backlog count (events pending >24h)
  Future<SystemStats> getSystemStats() async {
    try {
      final response = await _supabase.rpc('get_system_statistics');
      final data = response as Map<String, dynamic>;

      return SystemStats(
        totalEvents: data['total_events'] ?? 0,
        pendingEvents: data['pending_events'] ?? 0,
        approvedEvents: data['approved_events'] ?? 0,
        rejectedEvents: data['rejected_events'] ?? 0,
        totalModerators: data['total_moderators'] ?? 0,
        activeModerators: data['active_moderators'] ?? 0,
        avgReviewTimeHours: (data['avg_review_time_hours'] ?? 0).toDouble(),
        eventsOlderThan24h: data['events_older_than_24h'] ?? 0,
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch system stats: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch system stats: $e');
    }
  }

  /// Get activity log entries (moderation + admin actions)
  ///
  /// Returns combined stream of moderation and admin actions sorted by timestamp.
  /// Supports filtering by action type (approved, rejected, promoted, removed)
  /// and date range filtering.
  ///
  /// Each entry includes actor name and target (event title or username).
  Future<List<ActivityLogEntry>> getActivityLog({
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final entries = <ActivityLogEntry>[];

      // Fetch moderation log entries (if not filtered to admin actions only)
      if (actionType == null ||
          actionType == 'approved' ||
          actionType == 'rejected') {
        var moderationQuery = _supabase
            .from('moderation_log')
            .select('''
              id,
              event_id,
              moderator_id,
              action,
              rejection_reason,
              created_at,
              events!inner(title),
              profiles!moderation_log_moderator_id_fkey(full_name)
            ''');

        // Apply filters
        if (actionType != null) {
          moderationQuery = moderationQuery.eq('action', actionType);
        }
        if (startDate != null) {
          moderationQuery = moderationQuery.gte('created_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          moderationQuery = moderationQuery.lte('created_at', endDate.toIso8601String());
        }

        final moderationResponse = await moderationQuery.order('created_at', ascending: false);

        for (final item in moderationResponse as List) {
          final event = item['events'] as Map<String, dynamic>?;
          final profile = item['profiles'] as Map<String, dynamic>?;

          entries.add(ActivityLogEntry(
            id: item['id'] as String,
            type: 'moderation',
            actorId: item['moderator_id'] as String,
            actorName: profile?['full_name'] as String? ?? 'Moderatore sconosciuto',
            action: item['action'] as String,
            timestamp: DateTime.parse(item['created_at'] as String),
            eventId: item['event_id'] as String?,
            eventTitle: event?['title'] as String?,
            rejectionReason: item['rejection_reason'] as String?,
          ));
        }
      }

      // Fetch admin log entries (if not filtered to moderation actions only)
      if (actionType == null ||
          actionType == 'promoted' ||
          actionType == 'removed') {
        var adminQuery = _supabase.from('admin_log').select('''
              id,
              admin_id,
              target_user_id,
              action,
              old_role,
              new_role,
              created_at,
              admin_profiles:profiles!admin_log_admin_id_fkey(full_name),
              target_profiles:profiles!admin_log_target_user_id_fkey(full_name)
            ''');

        // Apply filters
        if (actionType != null) {
          adminQuery = adminQuery.eq('action', actionType);
        }
        if (startDate != null) {
          adminQuery = adminQuery.gte('created_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          adminQuery = adminQuery.lte('created_at', endDate.toIso8601String());
        }

        final adminResponse = await adminQuery.order('created_at', ascending: false);

        for (final item in adminResponse as List) {
          final adminProfile = item['admin_profiles'] as Map<String, dynamic>?;
          final targetProfile = item['target_profiles'] as Map<String, dynamic>?;

          entries.add(ActivityLogEntry(
            id: item['id'] as String,
            type: 'admin',
            actorId: item['admin_id'] as String,
            actorName: adminProfile?['full_name'] as String? ?? 'Admin sconosciuto',
            action: item['action'] as String,
            timestamp: DateTime.parse(item['created_at'] as String),
            targetUserId: item['target_user_id'] as String?,
            targetUserName: targetProfile?['full_name'] as String?,
            oldRole: item['old_role'] as String?,
            newRole: item['new_role'] as String,
          ));
        }
      }

      // Sort all entries by timestamp DESC
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return entries;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch activity log: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch activity log: $e');
    }
  }
}

/// Provider for AdminRepository
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminRepository(supabase);
});
