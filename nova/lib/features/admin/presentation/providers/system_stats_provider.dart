// =====================================================================
// System Stats Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Provider for system-wide statistics
// Architecture: Riverpod FutureProvider with periodic refresh
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';

/// Provider for system-wide statistics
///
/// Calls get_system_statistics() RPC function to fetch:
/// - Event counts (total, pending, approved, rejected)
/// - Moderator counts (total, active in last 7 days)
/// - Average review time in hours
/// - Backlog count (events pending >24h)
///
/// Note: This is a FutureProvider that refreshes when invalidated.
/// For real-time updates, AdminPanelScreen should invalidate this
/// provider periodically or on user action.
final systemStatsProvider = FutureProvider<SystemStats>((ref) async {
  final repository = ref.watch(adminRepositoryProvider);
  return repository.getSystemStats();
});

/// Provider for periodic refresh of system stats
///
/// Auto-refreshes every 30 seconds to keep statistics current
final systemStatsAutoRefreshProvider =
    StreamProvider<SystemStats>((ref) async* {
  while (true) {
    // Invalidate and wait for new stats
    ref.invalidate(systemStatsProvider);
    final stats = await ref.watch(systemStatsProvider.future);
    yield stats;

    // Wait 30 seconds before next refresh
    await Future.delayed(const Duration(seconds: 30));
  }
});
