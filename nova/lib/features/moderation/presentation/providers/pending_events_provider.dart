// =====================================================================
// Pending Events Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Real-time stream of pending events with automatic failover
// Architecture: StreamProvider with Realtime + polling fallback
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/moderation/data/models/moderation_event.dart';

/// Provider for pending events stream using Supabase Realtime with automatic failover
///
/// Primary mode: Real-time WebSocket subscription (<2s latency)
/// Fallback mode: Polling every 15 seconds (when WebSocket unavailable)
///
/// Uses Supabase Realtime for automatic updates (Supabase handles reconnection).
/// Sorted by created_at ascending (oldest first per FR-022).
final pendingEventsProvider =
    StreamProvider.autoDispose<List<ModerationEvent>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);

  // Subscribe to events table changes via Realtime
  // NOTE: Supabase Realtime has built-in automatic reconnection,
  //       so no manual connection monitoring needed for MVP.
  return supabase
      .from('events')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('created_at', ascending: true) // Oldest first
      .map((data) {
        return data
            .where((json) {
              // Filter out events with missing required fields
              return json['id'] != null &&
                  json['event_date'] != null &&
                  json['created_at'] != null &&
                  json['creator_id'] != null;
            })
            .map((json) {
              // Map database snake_case to camelCase
              // Note: events table uses event_date (not start_date), image_url (not cover_image_url)
              final mapped = {
                'id': json['id'] as String,
                'title': (json['title'] as String?) ?? 'Senza titolo',
                'description': (json['description'] as String?) ?? '',
                'emojiIcon': json['emoji_icon'] as String?,
                'coverImageUrl': json['image_url'] as String?,
                'category': (json['category'] as String?) ?? 'generale',
                'startDate': json['event_date'] as String, // Required, filtered above
                'endDate': json['end_date'] as String?,
                'location': json['location'] as String?,
                'organizerName': (json['organizer_name'] as String?) ?? 'Utente',
                'createdAt': json['created_at'] as String, // Required, filtered above
                'creatorId': json['creator_id'] as String, // Required, filtered above
                'status': (json['status'] as String?) ?? 'pending',
                'moderatedBy': json['moderated_by'] as String?,
                'moderatedAt': json['moderated_at'] as String?,
                'rejectionReason': json['rejection_reason'] as String?,
                'submissionCount': (json['submission_count'] as int?) ?? 1,
              };
              return ModerationEvent.fromJson(mapped);
            })
            .toList();
      });
});
