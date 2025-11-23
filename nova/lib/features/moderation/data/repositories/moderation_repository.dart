// =====================================================================
// ModerationRepository - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Data access layer for moderation operations
// Architecture: Repository pattern with Supabase RPC calls
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/providers/supabase_provider.dart';
import 'package:nova/features/moderation/data/models/moderation_event.dart';
import 'package:nova/features/moderation/domain/entities/moderation_action.dart';

/// Custom exceptions for moderation errors
class EventAlreadyModeratedException implements Exception {
  final String message;
  EventAlreadyModeratedException(this.message);

  @override
  String toString() => message;
}

class ConcurrentModerationException implements Exception {
  final String message;
  ConcurrentModerationException(this.message);

  @override
  String toString() => message;
}

class SelfModerationException implements Exception {
  final String message;
  SelfModerationException(this.message);

  @override
  String toString() => message;
}

/// Repository for moderation operations
///
/// Handles fetching pending events and performing moderation actions
/// with proper error handling for concurrent modification scenarios.
class ModerationRepository {
  final SupabaseClient _supabase;

  ModerationRepository(this._supabase);

  /// Get all pending events for moderation queue
  ///
  /// Sorted by created_at ascending (oldest first per FR-022).
  /// Returns empty list if no pending events.
  Future<List<ModerationEvent>> getPendingEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select(
              'id, title, description, emoji_icon, cover_image_url, category, start_date, end_date, location, organizer_name, created_at, created_by, status, moderated_by, moderated_at, rejection_reason, submission_count')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => ModerationEvent.fromJson(_mapDatabaseFields(json)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pending events: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch pending events: $e');
    }
  }

  /// Moderate an event (approve or reject)
  ///
  /// Calls the `moderate_event` database function which handles:
  /// - Optimistic locking (prevents concurrent modification)
  /// - Self-moderation prevention (cannot moderate own events)
  /// - Status validation (cannot re-moderate already moderated events)
  /// - Automatic logging to moderation_log table
  ///
  /// Throws:
  /// - [EventAlreadyModeratedException] if event already moderated
  /// - [SelfModerationException] if trying to moderate own event
  /// - [ConcurrentModerationException] if another moderator is reviewing
  Future<void> moderateEvent(
    String eventId,
    ModerationAction action,
    String? rejectionReason,
  ) async {
    try {
      await _supabase.rpc('moderate_event', params: {
        'p_event_id': eventId,
        'p_action': action.toString(),
        'p_rejection_reason': rejectionReason,
      });
    } on PostgrestException catch (e) {
      // Parse error message to throw specific exceptions
      final errorMessage = e.message.toLowerCase();

      if (errorMessage.contains('already moderated') ||
          errorMessage.contains('not pending')) {
        throw EventAlreadyModeratedException(
          'Questo evento è già stato moderato da un altro moderatore.',
        );
      } else if (errorMessage.contains('cannot moderate your own') ||
          errorMessage.contains('self-moderation')) {
        throw SelfModerationException(
          'Non puoi moderare i tuoi eventi.',
        );
      } else if (errorMessage.contains('lock not available') ||
          errorMessage.contains('concurrent')) {
        throw ConcurrentModerationException(
          'Un altro moderatore sta revisionando questo evento.',
        );
      }

      // Generic error
      throw Exception('Errore durante la moderazione: ${e.message}');
    } catch (e) {
      // Re-throw custom exceptions
      if (e is EventAlreadyModeratedException ||
          e is SelfModerationException ||
          e is ConcurrentModerationException) {
        rethrow;
      }

      throw Exception('Errore durante la moderazione: $e');
    }
  }

  /// Get moderator statistics for current user
  ///
  /// Returns statistics like reviews today, reviews this week, total reviews, approval rate.
  Future<Map<String, dynamic>> getModeratorStats() async {
    try {
      final response = await _supabase.rpc('get_moderator_stats');
      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch moderator stats: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch moderator stats: $e');
    }
  }

  /// Map database snake_case fields to camelCase for model
  Map<String, dynamic> _mapDatabaseFields(Map<String, dynamic> json) {
    return {
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
      'createdBy': json['created_by'],
      'status': json['status'],
      'moderatedBy': json['moderated_by'],
      'moderatedAt': json['moderated_at'],
      'rejectionReason': json['rejection_reason'],
      'submissionCount': json['submission_count'],
    };
  }
}

/// Provider for ModerationRepository
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ModerationRepository(supabase);
});
