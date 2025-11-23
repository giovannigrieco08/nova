// =====================================================================
// Activity Log Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Real-time stream of activity log entries (moderation + admin)
// Architecture: StreamProvider subscribing to Supabase Realtime
// =====================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/providers/supabase_provider.dart';
import 'package:nova/features/admin/domain/entities/activity_log_entry.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';
import 'package:nova/features/admin/presentation/providers/activity_log_filter_provider.dart';

/// Provider for activity log real-time stream
///
/// Subscribes to both moderation_log and admin_log tables via Supabase Realtime.
/// Returns combined list sorted by timestamp DESC.
///
/// Updates automatically when:
/// - Moderator approves/rejects an event
/// - Admin promotes/removes a user role
final activityLogProvider = StreamProvider<List<ActivityLogEntry>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final repository = ref.watch(adminRepositoryProvider);
  final filter = ref.watch(activityLogFilterProvider);

  // Create a stream controller for manual updates
  final controller = StreamController<List<ActivityLogEntry>>();

  // Fetch initial data
  Future<void> fetchData() async {
    try {
      final entries = await repository.getActivityLog(
        actionType: filter.actionType,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
      if (!controller.isClosed) {
        controller.add(entries);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Initial fetch
  fetchData();

  // Subscribe to moderation_log changes
  final moderationSubscription = supabase
      .channel('admin_activity_log_moderation')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'moderation_log',
        callback: (_) => fetchData(),
      )
      .subscribe();

  // Subscribe to admin_log changes
  final adminSubscription = supabase
      .channel('admin_activity_log_admin')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'admin_log',
        callback: (_) => fetchData(),
      )
      .subscribe();

  // Cleanup on provider disposal
  ref.onDispose(() {
    moderationSubscription.unsubscribe();
    adminSubscription.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
