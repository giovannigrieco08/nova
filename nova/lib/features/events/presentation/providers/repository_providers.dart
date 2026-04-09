// Riverpod Providers: Presentation-layer providers for events feature
// Feature: 004-event-creation-moderation
// Purpose: Presentation-only providers (datasource/repository providers moved to data layer)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/providers/core_providers.dart';

// Re-export data providers so existing consumers continue to work
export '../../data/providers/events_data_providers.dart';

// =============================================================================
// UTILITY PROVIDERS (For common queries)
// =============================================================================
// currentUserIdProvider - imported from core_providers.dart
// currentUserIdOrNullProvider - imported from core_providers.dart

/// Provider for checking if current user is a moderator
///
/// This queries the user_roles table to check if user has 'moderator' or 'admin' role.
/// Returns false if user is not authenticated or not a moderator.
final isModeratorProvider = FutureProvider<bool>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdOrNullProvider);

  if (userId == null) return false;

  try {
    final response = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .or('role.eq.moderator,role.eq.admin')
        .maybeSingle();

    return response != null;
  } catch (e) {
    return false;
  }
});
