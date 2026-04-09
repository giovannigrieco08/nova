import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_help_request_model.dart';
import '../../domain/entities/event_help_request.dart';

/// Repository for event help requests and offers.
///
/// Encapsulates all Supabase calls related to the help system,
/// keeping presentation-layer notifiers free of direct DB access.
class EventHelpRepository {
  final SupabaseClient _supabase;

  EventHelpRepository(this._supabase);

  // ---------------------------------------------------------------------------
  // Help requests
  // ---------------------------------------------------------------------------

  /// Fetch help requests for a specific event.
  Future<List<EventHelpRequest>> getHelpRequests(String eventId) async {
    final response = await _supabase
        .from('event_help_requests')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => EventHelpRequestModel.fromJson(json).toEntity())
        .toList();
  }

  /// Subscribe to real-time changes for help requests of an event.
  Stream<List<EventHelpRequest>> watchHelpRequests(String eventId) {
    return _supabase
        .from('event_help_requests')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map((data) => data
            .map((json) => EventHelpRequestModel.fromJson(json).toEntity())
            .toList());
  }

  /// Batch fetch unfulfilled help requests for multiple events.
  Future<Map<String, List<EventHelpRequest>>> batchGetUnfulfilledRequests(
      List<String> eventIds) async {
    if (eventIds.isEmpty) return {};

    final response = await _supabase
        .from('event_help_requests')
        .select()
        .inFilter('event_id', eventIds)
        .eq('is_fulfilled', false)
        .order('created_at', ascending: true);

    final result = <String, List<EventHelpRequest>>{};
    for (final eventId in eventIds) {
      result[eventId] = [];
    }

    for (final json in response as List) {
      final request = EventHelpRequestModel.fromJson(json).toEntity();
      result[request.eventId]?.add(request);
    }

    return result;
  }

  /// Get count of unfulfilled help requests for an event.
  Future<int> getUnfulfilledCount(String eventId) async {
    final response = await _supabase
        .from('event_help_requests')
        .select()
        .eq('event_id', eventId)
        .eq('is_fulfilled', false);

    return (response as List).length;
  }

  /// Mark a help request as fulfilled.
  Future<void> markRequestFulfilled({
    required String requestId,
    required String fulfilledBy,
  }) async {
    await _supabase.from('event_help_requests').update({
      'is_fulfilled': true,
      'fulfilled_by': fulfilledBy,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ---------------------------------------------------------------------------
  // Help offers
  // ---------------------------------------------------------------------------

  /// Fetch offers for a specific help request (with profile join).
  Future<List<EventHelpOffer>> getOffers(String requestId) async {
    final response = await _supabase
        .from('event_help_offers')
        .select(
            '*, profile:profiles!user_id(user_id, full_name, avatar_url, class)')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => EventHelpOfferModel.fromJson(json).toEntity())
        .toList();
  }

  /// Subscribe to real-time changes for offers of a request.
  Stream<List<Map<String, dynamic>>> watchOffers(String requestId) {
    return _supabase
        .from('event_help_offers')
        .stream(primaryKey: ['id']).eq('request_id', requestId);
  }

  /// Create a new help offer.
  /// Returns null on success, or an error message on failure.
  Future<String?> createOffer({
    required String requestId,
    required String userId,
    required String contactType,
    required String contactInfo,
    String? message,
  }) async {
    if (contactInfo.trim().isEmpty) {
      return 'Inserisci il tuo contatto';
    }

    try {
      debugPrint('[HELP_OFFER] Inserting into event_help_offers...');
      await _supabase.from('event_help_offers').insert({
        'request_id': requestId,
        'user_id': userId,
        'message': message,
        'contact_type': contactType,
        'contact_info': contactInfo.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[HELP_OFFER] Offer created successfully!');
      return null;
    } on PostgrestException catch (e) {
      debugPrint(
          '[HELP_OFFER] PostgrestException: code=${e.code}, message=${e.message}');
      if (e.code == '23503') {
        return 'Completa il tuo profilo prima di offrire aiuto';
      } else if (e.code == '23505') {
        return 'Hai già offerto aiuto per questa richiesta';
      } else if (e.code == '42501' || e.message.contains('policy')) {
        return 'Non puoi offrire aiuto per questa richiesta';
      }
      return 'Errore database: ${e.message}';
    } catch (e) {
      debugPrint('[HELP_OFFER] Unexpected error: $e');
      return 'Errore imprevisto: $e';
    }
  }

  /// Accept an offer.
  Future<void> acceptOffer(String offerId) async {
    await _supabase.from('event_help_offers').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', offerId);
  }

  /// Decline an offer.
  Future<void> declineOffer(String offerId) async {
    await _supabase.from('event_help_offers').update({
      'status': 'declined',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', offerId);
  }

  /// Withdraw (delete) an offer.
  Future<void> withdrawOffer(String offerId) async {
    await _supabase.from('event_help_offers').delete().eq('id', offerId);
  }

  /// Check if a user has already offered help for a request.
  Future<bool> hasUserOffered({
    required String requestId,
    required String userId,
  }) async {
    final response = await _supabase
        .from('event_help_offers')
        .select()
        .eq('request_id', requestId)
        .eq('user_id', userId);

    return (response as List).isNotEmpty;
  }
}
