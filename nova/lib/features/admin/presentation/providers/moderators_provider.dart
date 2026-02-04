// =====================================================================
// Moderators Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Stream provider for real-time moderator list
// Architecture: Riverpod StreamProvider with Supabase Realtime subscription
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';

/// Provider for real-time moderator list with statistics
///
/// Subscribes to user_roles table (filtered by role='moderator')
/// and joins with profiles and moderator_stats for complete data.
///
/// Updates automatically when:
/// - New moderator is promoted
/// - Moderator is removed
/// - Statistics change (via moderator_stats table updates)
final moderatorsProvider = StreamProvider<List<Moderator>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  return supabase
      .from('user_roles')
      .stream(primaryKey: ['id'])
      .eq('role', 'moderator')
      .map((data) async {
        // For each user_role entry, fetch related profile and stats
        final moderators = <Moderator>[];

        for (final roleEntry in data) {
          final userId = roleEntry['user_id'] as String;

          try {
            // Fetch profile data
            final profileResponse = await supabase
                .from('profiles')
                .select('full_name, email, class_name')
                .eq('id', userId)
                .single();

            // Fetch moderator stats (may not exist for new moderators)
            final statsResponse = await supabase
                .from('moderator_stats')
                .select(
                    'total_reviews, reviews_this_week, approval_rate_percent, last_review_at')
                .eq('user_id', userId)
                .maybeSingle();

            moderators.add(Moderator(
              userId: userId,
              fullName: profileResponse['full_name'] as String,
              email: profileResponse['email'] as String,
              className: profileResponse['class_name'] as String,
              totalReviews: statsResponse?['total_reviews'] ?? 0,
              reviewsThisWeek: statsResponse?['reviews_this_week'] ?? 0,
              approvalRatePercent:
                  (statsResponse?['approval_rate_percent'] ?? 0).toDouble(),
              lastReviewAt: statsResponse?['last_review_at'] != null
                  ? DateTime.parse(statsResponse!['last_review_at'] as String)
                  : null,
            ));
          } catch (e) {
            // Skip this moderator if data fetch fails
            continue;
          }
        }

        // Sort by full name
        moderators.sort((a, b) => a.fullName.compareTo(b.fullName));
        return moderators;
      })
      .asyncMap((future) => future);
});
