// Provider: EventEngagementProvider
// Feature: Event engagement metrics
// Purpose: Efficiently fetch and cache like/comment/participation counts for events

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/providers/core_providers.dart';

/// Engagement data for a single event
class EventEngagement {
  final int likeCount;
  final int commentCount;
  final int participantCount;
  final bool isLiked;
  final bool isParticipating;

  const EventEngagement({
    this.likeCount = 0,
    this.commentCount = 0,
    this.participantCount = 0,
    this.isLiked = false,
    this.isParticipating = false,
  });
}

/// Provider for a single event's engagement data
/// Uses family modifier to cache per event ID
final eventEngagementProvider =
    FutureProvider.family<EventEngagement, String>((ref, eventId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  // Fetch all engagement data in parallel
  final futures = await Future.wait([
    // Like count
    supabase.from('likes').select('id').eq('event_id', eventId),
    // Comment count
    supabase.from('comments').select('id').eq('event_id', eventId),
    // Participant count
    supabase.from('participations').select('id').eq('event_id', eventId),
    // Is liked by current user
    if (userId != null)
      supabase
          .from('likes')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
    else
      Future.value([]),
    // Is participating by current user
    if (userId != null)
      supabase
          .from('participations')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
    else
      Future.value([]),
  ]);

  return EventEngagement(
    likeCount: (futures[0]).length,
    commentCount: (futures[1]).length,
    participantCount: (futures[2]).length,
    isLiked: (futures[3]).isNotEmpty,
    isParticipating: (futures[4]).isNotEmpty,
  );
});

/// Provider for batch fetching engagement for multiple events
/// More efficient for feed screens
final batchEventEngagementProvider =
    FutureProvider.family<Map<String, EventEngagement>, List<String>>(
        (ref, eventIds) async {
  if (eventIds.isEmpty) return {};

  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  // Fetch all counts in parallel using batch queries
  final futures = await Future.wait([
    // All likes for these events
    supabase.from('likes').select('event_id').inFilter('event_id', eventIds),
    // All comments for these events
    supabase.from('comments').select('event_id').inFilter('event_id', eventIds),
    // All participations for these events
    supabase
        .from('participations')
        .select('event_id')
        .inFilter('event_id', eventIds),
    // User's likes
    if (userId != null)
      supabase
          .from('likes')
          .select('event_id')
          .inFilter('event_id', eventIds)
          .eq('user_id', userId)
    else
      Future.value([]),
    // User's participations
    if (userId != null)
      supabase
          .from('participations')
          .select('event_id')
          .inFilter('event_id', eventIds)
          .eq('user_id', userId)
    else
      Future.value([]),
  ]);

  final likes = futures[0];
  final comments = futures[1];
  final participations = futures[2];
  final userLikes = futures[3];
  final userParticipations = futures[4];

  // Count per event
  final likeCountMap = <String, int>{};
  final commentCountMap = <String, int>{};
  final participantCountMap = <String, int>{};
  final userLikedSet = <String>{};
  final userParticipatingSet = <String>{};

  for (final like in likes) {
    final eventId = like['event_id'] as String;
    likeCountMap[eventId] = (likeCountMap[eventId] ?? 0) + 1;
  }

  for (final comment in comments) {
    final eventId = comment['event_id'] as String;
    commentCountMap[eventId] = (commentCountMap[eventId] ?? 0) + 1;
  }

  for (final participation in participations) {
    final eventId = participation['event_id'] as String;
    participantCountMap[eventId] = (participantCountMap[eventId] ?? 0) + 1;
  }

  for (final like in userLikes) {
    userLikedSet.add(like['event_id'] as String);
  }

  for (final participation in userParticipations) {
    userParticipatingSet.add(participation['event_id'] as String);
  }

  // Build engagement map
  final result = <String, EventEngagement>{};
  for (final eventId in eventIds) {
    result[eventId] = EventEngagement(
      likeCount: likeCountMap[eventId] ?? 0,
      commentCount: commentCountMap[eventId] ?? 0,
      participantCount: participantCountMap[eventId] ?? 0,
      isLiked: userLikedSet.contains(eventId),
      isParticipating: userParticipatingSet.contains(eventId),
    );
  }

  return result;
});
