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
import '../../data/repositories/event_help_repository.dart';
import '../../domain/entities/event_help_request.dart';

// =============================================================================
// REPOSITORY PROVIDER
// =============================================================================

final eventHelpRepositoryProvider = Provider<EventHelpRepository>((ref) {
  return EventHelpRepository(Supabase.instance.client);
});

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
  final EventHelpRepository _repository;
  final String eventId;
  StreamSubscription? _subscription;

  EventHelpRequestsNotifier({
    required EventHelpRepository repository,
    required this.eventId,
  })  : _repository = repository,
        super(const EventHelpRequestsState(isLoading: true)) {
    _loadHelpRequests();
    _subscribeToChanges();
  }

  Future<void> _loadHelpRequests() async {
    try {
      final requests = await _repository.getHelpRequests(eventId);
      state = state.copyWith(requests: requests, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento: $e',
      );
    }
  }

  void _subscribeToChanges() {
    _subscription = _repository.watchHelpRequests(eventId).listen((requests) {
      state = state.copyWith(requests: requests);
    });
  }

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
    final repository = ref.watch(eventHelpRepositoryProvider);
    return EventHelpRequestsNotifier(
      repository: repository,
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
  final EventHelpRepository _repository;
  final String requestId;
  StreamSubscription? _subscription;

  HelpOffersNotifier({
    required EventHelpRepository repository,
    required this.requestId,
  })  : _repository = repository,
        super(const HelpOffersState(isLoading: true)) {
    _loadOffers();
    _subscribeToChanges();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _repository.getOffers(requestId);
      state = state.copyWith(offers: offers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento: $e',
      );
    }
  }

  void _subscribeToChanges() {
    _subscription = _repository.watchOffers(requestId).listen((_) async {
      // Reload with profile info since stream doesn't include joins
      await _loadOffers();
    });
  }

  Future<String?> createOffer({
    required String userId,
    required String contactType,
    required String contactInfo,
    String? message,
  }) async {
    return _repository.createOffer(
      requestId: requestId,
      userId: userId,
      contactType: contactType,
      contactInfo: contactInfo,
      message: message,
    );
  }

  Future<bool> acceptOffer(String offerId) async {
    try {
      await _repository.acceptOffer(offerId);
      // Also mark the request as fulfilled
      final offer = state.offers.firstWhere((o) => o.id == offerId);
      await _repository.markRequestFulfilled(
        requestId: requestId,
        fulfilledBy: offer.userId,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'accettazione: $e');
      return false;
    }
  }

  Future<bool> declineOffer(String offerId) async {
    try {
      await _repository.declineOffer(offerId);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Errore nel rifiuto: $e');
      return false;
    }
  }

  Future<bool> withdrawOffer(String offerId) async {
    try {
      await _repository.withdrawOffer(offerId);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Errore nel ritiro: $e');
      return false;
    }
  }

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
    final repository = ref.watch(eventHelpRepositoryProvider);
    return HelpOffersNotifier(
      repository: repository,
      requestId: requestId,
    );
  },
);

// =============================================================================
// BATCH PROVIDER (for feed efficiency)
// =============================================================================

/// Batch fetch help requests for multiple events (for feed display).
/// Uses comma-separated string key to prevent infinite rebuilds.
final batchHelpRequestsKeyProvider =
    FutureProvider.family<Map<String, List<EventHelpRequest>>, String>(
  (ref, eventIdsKey) async {
    if (eventIdsKey.isEmpty) return {};

    final eventIds = eventIdsKey.split(',');
    final repository = ref.watch(eventHelpRepositoryProvider);

    try {
      return await repository.batchGetUnfulfilledRequests(eventIds);
    } catch (e) {
      return {};
    }
  },
);

// =============================================================================
// HELPER PROVIDERS
// =============================================================================

/// Check if current user has already offered help for a request.
final hasUserOfferedProvider = FutureProvider.family<bool, String>(
  (ref, requestId) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final repository = ref.watch(eventHelpRepositoryProvider);
    return repository.hasUserOffered(requestId: requestId, userId: userId);
  },
);

/// Get unfulfilled help requests count for an event (for badge display).
final unfullfilledHelpRequestsCountProvider =
    FutureProvider.family<int, String>(
  (ref, eventId) async {
    final repository = ref.watch(eventHelpRepositoryProvider);
    return repository.getUnfulfilledCount(eventId);
  },
);
