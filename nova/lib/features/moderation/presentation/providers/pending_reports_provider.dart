// =====================================================================
// Pending Reports Provider - Moderation Queue for Reports
// =====================================================================
// Purpose: Fetch pending reports for moderators to review
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/moderation_report.dart';
import '../../data/repositories/moderation_repository.dart';

export '../../data/repositories/moderation_repository.dart' show ReportStats;

/// Repository provider for moderation.
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(Supabase.instance.client);
});

/// Provider for fetching pending reports with user information.
final pendingReportsProvider =
    FutureProvider.autoDispose<List<ModerationReport>>((ref) async {
  final repository = ref.watch(moderationRepositoryProvider);
  return repository.getPendingReports();
});

/// Provider for report moderation stats.
final reportStatsProvider =
    FutureProvider.autoDispose<ReportStats>((ref) async {
  final repository = ref.watch(moderationRepositoryProvider);
  return repository.getStats();
});
