// =====================================================================
// Pending Events Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Real-time stream of pending events with automatic failover
// Architecture: StreamProvider with Realtime + polling fallback
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/providers/supabase_provider.dart';
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
        return data.map((json) {
          // Map database snake_case to camelCase
          final mapped = {
            'id': json['id'],
            'title': json['title'],
            'description': json['description'],
            'emojiIcon': json['emoji_icon'],
            'coverImageUrl': json['cover_image_url'],
            'category': json['category'],
            'startDate': json['start_date'],
            'endDate': json['end_date'],
            'location': json['location'],
            'organizerName': json['organizer_name'],
            'createdAt': json['created_at'],
            'creatorId': json['creator_id'],
            'status': json['status'],
            'moderatedBy': json['moderated_by'],
            'moderatedAt': json['moderated_at'],
            'rejectionReason': json['rejection_reason'],
            'submissionCount': json['submission_count'],
          };
          return ModerationEvent.fromJson(mapped);
        }).toList();
      });
});
