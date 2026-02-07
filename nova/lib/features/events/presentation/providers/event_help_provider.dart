// Provider: EventHelpProvider
// Feature: Event Help Requests (Bacheche integration)
// Purpose: Real-time state management for help requests and offers
//
// Features:
// - Real-time updates via Supabase Realtime
// - Fetch help requests for an event
// - Create/manage help offers
// - Notification when offers are received

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/event_help_request_model.dart';
import '../../domain/entities/event_help_request.dart';

// =============================================================================
// HELP REQUESTS PROVIDER (for a specific event)
// =============================================================================

/// State for help requests of a specific event
class EventHelpRequestsState {
  final List<EventHelpRequest> requests;
  final bool isLoading;
  final String? error;

  const EventHelpRequestsState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  EventHelpRequestsState copyWith({
    List<EventHelpRequest>? requests,
    bool? isLoading,
    String? error,
  }) {
    return EventHelpRequestsState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for help requests of a specific event
class EventHelpRequestsNotifier extends StateNotifier<EventHelpRequestsState> {
  final SupabaseClient _supabase;
  final String eventId;
  StreamSubscription? _subscription;

  EventHelpRequestsNotifier({
    required SupabaseClient supabase,
    required this.eventId,
  })  : _supabase = supabase,
        super(const EventHelpRequestsState(isLoading: true)) {
    _loadHelpRequests();
    _subscribeToChanges();
  }

  /// Load initial help requests
  Future<void> _loadHelpRequests() async {
    try {
      final response = await _supabase
          .from('event_help_requests')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);

      final requests = (response as List)
          .map((json) => EventHelpRequestModel.fromJson(json).toEntity())
          .toList();

      state = state.copyWith(requests: requests, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento: $e',
      );
    }
  }

  /// Subscribe to real-time changes
  void _subscribeToChanges() {
    _subscription = _supabase
        .from('event_help_requests')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .listen((data) {
          final requests = data
              .map((json) => EventHelpRequestModel.fromJson(json).toEntity())
              .toList();
          state = state.copyWith(requests: requests);
        });
  }

  /// Refresh help requests
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadHelpRequests();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider family for help requests of a specific event
final eventHelpRequestsProvider = StateNotifierProvider.family<
    EventHelpRequestsNotifier, EventHelpRequestsState, String>(
  (ref, eventId) {
    final supabase = Supabase.instance.client;
    return EventHelpRequestsNotifier(
      supabase: supabase,
      eventId: eventId,
    );
  },
);

// =============================================================================
// HELP OFFERS PROVIDER (for a specific request)
// =============================================================================

/// State for help offers of a specific request
class HelpOffersState {
  final List<EventHelpOffer> offers;
  final bool isLoading;
  final String? error;

  const HelpOffersState({
    this.offers = const [],
    this.isLoading = false,
    this.error,
  });

  HelpOffersState copyWith({
    List<EventHelpOffer>? offers,
    bool? isLoading,
    String? error,
  }) {
    return HelpOffersState(
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for help offers of a specific request
class HelpOffersNotifier extends StateNotifier<HelpOffersState> {
  final SupabaseClient _supabase;
  final String requestId;
  StreamSubscription? _subscription;

  HelpOffersNotifier({
    required SupabaseClient supabase,
    required this.requestId,
  })  : _supabase = supabase,
        super(const HelpOffersState(isLoading: true)) {
    _loadOffers();
    _subscribeToChanges();
  }

  /// Load initial offers
  Future<void> _loadOffers() async {
    try {
      final response = await _supabase
          .from('event_help_offers')
          .select(
              '*, profile:profiles!user_id(user_id, full_name, avatar_url, class)')
          .eq('request_id', requestId)
          .order('created_at', ascending: true);

      final offers = (response as List)
          .map((json) => EventHelpOfferModel.fromJson(json).toEntity())
          .toList();

      state = state.copyWith(offers: offers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento: $e',
      );
    }
  }

  /// Subscribe to real-time changes
  void _subscribeToChanges() {
    _subscription = _supabase
        .from('event_help_offers')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .listen((data) async {
          // Reload with profile info since stream doesn't include joins
          await _loadOffers();
        });
  }

  /// Create a new offer
  /// Returns null on success, or an error message on failure
  ///
  /// [contactType] - Either 'instagram' or 'whatsapp'
  /// [contactInfo] - Username for Instagram, phone number for WhatsApp
  Future<String?> createOffer({
    required String userId,
    required String contactType,
    required String contactInfo,
    String? message,
  }) async {
    // Validate contact info
    if (contactInfo.trim().isEmpty) {
      return 'Inserisci il tuo contatto';
    }

    try {
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
      return null; // Success
    } on PostgrestException catch (e) {
      // Specific error messages based on PostgreSQL error codes
      if (e.code == '23503') {
        // Foreign key violation - profile doesn't exist
        return 'Completa il tuo profilo prima di offrire aiuto';
      } else if (e.code == '23505') {
        // Unique constraint violation - duplicate offer
        return 'Hai già offerto aiuto per questa richiesta';
      } else if (e.code == '42501' || e.message.contains('policy')) {
        // RLS policy violation
        return 'Non puoi offrire aiuto per questa richiesta';
      }
      return 'Errore database: ${e.message}';
    } catch (e) {
      return 'Errore imprevisto: $e';
    }
  }

  /// Accept an offer (for event creators)
  Future<bool> acceptOffer(String offerId) async {
    try {
      await _supabase.from('event_help_offers').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', offerId);

      // Also mark the request as fulfilled
      final offer = state.offers.firstWhere((o) => o.id == offerId);
      await _supabase.from('event_help_requests').update({
        'is_fulfilled': true,
        'fulfilled_by': offer.userId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'accettazione: $e');
      return false;
    }
  }

  /// Decline an offer (for event creators)
  Future<bool> declineOffer(String offerId) async {
    try {
      await _supabase.from('event_help_offers').update({
        'status': 'declined',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', offerId);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Errore nel rifiuto: $e');
      return false;
    }
  }

  /// Withdraw own offer
  Future<bool> withdrawOffer(String offerId) async {
    try {
      await _supabase.from('event_help_offers').delete().eq('id', offerId);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Errore nel ritiro: $e');
      return false;
    }
  }

  /// Refresh offers
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadOffers();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider family for help offers of a specific request
final helpOffersProvider =
    StateNotifierProvider.family<HelpOffersNotifier, HelpOffersState, String>(
  (ref, requestId) {
    final supabase = Supabase.instance.client;
    return HelpOffersNotifier(
      supabase: supabase,
      requestId: requestId,
    );
  },
);

// =============================================================================
// BATCH PROVIDER (for feed efficiency)
// =============================================================================

/// Batch fetch help requests for multiple events (for feed display)
/// Uses comma-separated string key to prevent infinite rebuilds
/// Returns a map of eventId -> list of unfulfilled help requests
final batchHelpRequestsKeyProvider =
    FutureProvider.family<Map<String, List<EventHelpRequest>>, String>(
  (ref, eventIdsKey) async {
    if (eventIdsKey.isEmpty) return {};

    final eventIds = eventIdsKey.split(',');
    final supabase = Supabase.instance.client;

    try {
      // Fetch all unfulfilled help requests for these events in one query
      final response = await supabase
          .from('event_help_requests')
          .select()
          .inFilter('event_id', eventIds)
          .eq('is_fulfilled', false)
          .order('created_at', ascending: true);

      // Group by event ID
      final result = <String, List<EventHelpRequest>>{};
      for (final eventId in eventIds) {
        result[eventId] = [];
      }

      for (final json in response as List) {
        final request = EventHelpRequestModel.fromJson(json).toEntity();
        result[request.eventId]?.add(request);
      }

      return result;
    } catch (e) {
      return {};
    }
  },
);

// =============================================================================
// HELPER PROVIDERS
// =============================================================================

/// Check if current user has already offered help for a request
final hasUserOfferedProvider = FutureProvider.family<bool, String>(
  (ref, requestId) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await supabase
        .from('event_help_offers')
        .select()
        .eq('request_id', requestId)
        .eq('user_id', userId);

    return (response as List).isNotEmpty;
  },
);

/// Get unfulfilled help requests count for an event (for badge display)
final unfullfilledHelpRequestsCountProvider =
    FutureProvider.family<int, String>(
  (ref, eventId) async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('event_help_requests')
        .select()
        .eq('event_id', eventId)
        .eq('is_fulfilled', false);

    return (response as List).length;
  },
);
