import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tos_status.dart';
import '../../data/repositories/tos_repository.dart';
import '../../domain/services/tos_service.dart';

/// Provider for TosRepository
final tosRepositoryProvider = Provider<TosRepository>((ref) {
  return TosRepository();
});

/// Provider for TosService
final tosServiceProvider = Provider<TosService>((ref) {
  return TosService(
    repository: ref.watch(tosRepositoryProvider),
  );
});

/// State for ToS operations
class TosState {
  const TosState({
    this.isLoading = false,
    this.isAccepted = false,
    this.error,
    this.status,
  });

  final bool isLoading;
  final bool isAccepted;
  final String? error;
  final TosStatus? status;

  TosState copyWith({
    bool? isLoading,
    bool? isAccepted,
    String? error,
    TosStatus? status,
  }) {
    return TosState(
      isLoading: isLoading ?? this.isLoading,
      isAccepted: isAccepted ?? this.isAccepted,
      error: error,
      status: status ?? this.status,
    );
  }
}

/// Notifier for managing ToS acceptance
class TosNotifier extends StateNotifier<TosState> {
  TosNotifier(this._service, this._ref) : super(const TosState());

  final TosService _service;
  final Ref _ref;

  /// Load ToS status
  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final status = await _service.getTosStatus();
      state = state.copyWith(
        isLoading: false,
        status: status,
        isAccepted: status.canCreateContent,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento: ${e.toString()}',
      );
    }
  }

  /// Accept ToS
  Future<bool> acceptTos() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.acceptTos();

      // Refresh status
      final newStatus = await _service.getTosStatus();

      state = state.copyWith(
        isLoading: false,
        isAccepted: true,
        status: newStatus,
      );

      // Invalidate related providers
      _ref.invalidate(tosStatusProvider);
      _ref.invalidate(canCreateContentProvider);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante l\'accettazione: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const TosState();
  }
}

/// Provider for ToS operations state
final tosNotifierProvider = StateNotifierProvider<TosNotifier, TosState>((ref) {
  return TosNotifier(ref.watch(tosServiceProvider), ref);
});

/// Provider for current ToS status
final tosStatusProvider = FutureProvider<TosStatus>((ref) async {
  final service = ref.watch(tosServiceProvider);
  return service.getTosStatus();
});

/// Provider to check if user can create content
final canCreateContentProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(tosServiceProvider);
  return service.canCreateContent();
});

/// Provider to check if ToS acceptance is needed
final needsTosAcceptanceProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(tosServiceProvider);
  return service.needsTosAcceptance();
});

/// Provider for ToS document URL
final tosDocumentUrlProvider = Provider<String>((ref) {
  final service = ref.watch(tosServiceProvider);
  return service.getTosDocumentUrl();
});

/// Provider for current ToS version
final currentTosVersionProvider = Provider<String>((ref) {
  final service = ref.watch(tosServiceProvider);
  return service.currentVersion;
});
