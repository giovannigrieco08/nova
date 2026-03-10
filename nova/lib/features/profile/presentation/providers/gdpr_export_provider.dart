// Provider: GDPRExportProvider
// Feature: 006-user-profile (US3 - GDPR Compliance)
// Purpose: Handles GDPR data export and account deletion functionality

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './profile_provider.dart' show profileRepositoryProvider;

/// Export metadata containing download URL
class GDPRExportMetadata {
  final String downloadUrl;

  const GDPRExportMetadata({required this.downloadUrl});
}

/// State class for GDPR export status
class GDPRExportState {
  final bool isExporting;
  final String? downloadUrl;
  final String? error;

  const GDPRExportState({
    this.isExporting = false,
    this.downloadUrl,
    this.error,
  });

  GDPRExportState copyWith({
    bool? isExporting,
    String? downloadUrl,
    String? error,
  }) {
    return GDPRExportState(
      isExporting: isExporting ?? this.isExporting,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: error ?? this.error,
    );
  }

  /// Convenience getters for settings_screen.dart API compatibility
  bool get isSuccess => downloadUrl != null && error == null && !isExporting;
  bool get isError => error != null;
  String? get errorMessage => error;
  GDPRExportMetadata? get metadata => downloadUrl != null
      ? GDPRExportMetadata(downloadUrl: downloadUrl!)
      : null;
}

/// GDPR Export Notifier
class GDPRExportNotifier extends StateNotifier<GDPRExportState> {
  GDPRExportNotifier() : super(const GDPRExportState());

  /// Request data export for user
  /// Alias: exportUserData for settings_screen.dart compatibility
  Future<void> exportUserData(String userId) => requestExport(userId);

  Future<void> requestExport(String userId) async {
    state = state.copyWith(isExporting: true, error: null);

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception('Sessione non valida. Effettua nuovamente il login.');
      }

      // Call GDPR export Edge Function
      final response = await supabase.functions.invoke(
        'export-user-data',
        body: {},
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception(
            errorData?['message'] ?? 'Errore durante l\'esportazione');
      }

      final data = response.data as Map<String, dynamic>;
      final downloadUrl = data['download_url'] as String?;

      if (downloadUrl == null) {
        throw Exception('URL di download non disponibile');
      }

      debugPrint('[GDPRExport] Export completed, URL: $downloadUrl');
      debugPrint('[GDPRExport] Summary: ${data['data_summary']}');

      state = state.copyWith(
        isExporting: false,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('[GDPRExport] Error: $e');
      state = state.copyWith(
        isExporting: false,
        error: _getExportErrorMessage(e),
      );
    }
  }

  String _getExportErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();

    if (message.contains('network') || message.contains('connection')) {
      return 'Errore di connessione. Verifica la tua connessione internet.';
    }
    if (message.contains('session') || message.contains('login')) {
      return 'Sessione scaduta. Effettua nuovamente il login.';
    }
    if (message.contains('timeout')) {
      return 'Richiesta scaduta. Riprova tra qualche minuto.';
    }

    return 'Errore durante l\'esportazione dei dati. Riprova più tardi.';
  }

  /// Clear export state
  void clearState() {
    state = const GDPRExportState();
  }
}

/// Provider for GDPR export functionality
final gdprExportProvider =
    StateNotifierProvider<GDPRExportNotifier, GDPRExportState>((ref) {
  return GDPRExportNotifier();
});

/// Account deletion state
class AccountDeletionState {
  final bool isDeleting;
  final bool isDeleted;
  final String? error;

  const AccountDeletionState({
    this.isDeleting = false,
    this.isDeleted = false,
    this.error,
  });

  AccountDeletionState copyWith({
    bool? isDeleting,
    bool? isDeleted,
    String? error,
  }) {
    return AccountDeletionState(
      isDeleting: isDeleting ?? this.isDeleting,
      isDeleted: isDeleted ?? this.isDeleted,
      error: error ?? this.error,
    );
  }

  /// Convenience getter for settings_screen.dart API compatibility
  String? get errorMessage => error;
}

/// Account Deletion Notifier
///
/// Handles soft deletion of user accounts per GDPR Article 17.
/// Sets `deleted_at` timestamp, allowing 30-day grace period for recovery.
class AccountDeletionNotifier extends StateNotifier<AccountDeletionState> {
  final Ref _ref;

  AccountDeletionNotifier(this._ref) : super(const AccountDeletionState());

  /// Soft delete user account
  /// Alias: softDeleteAccount for settings_screen.dart compatibility
  Future<void> softDeleteAccount(String userId) => deleteAccount(userId);

  /// Soft delete account by setting deleted_at timestamp
  ///
  /// The account will be permanently deleted after 30 days.
  /// User can cancel deletion by contacting support within grace period.
  Future<void> deleteAccount(String userId) async {
    debugPrint('[AccountDeletion] Starting deleteAccount for user: $userId');
    state = state.copyWith(isDeleting: true, error: null);

    try {
      // Get the profile repository
      final repository = _ref.read(profileRepositoryProvider);
      debugPrint('[AccountDeletion] Got repository, calling updateProfile...');

      final deletedAt = DateTime.now().toUtc().toIso8601String();
      debugPrint('[AccountDeletion] Setting deleted_at to: $deletedAt');

      // Set deleted_at timestamp for soft delete
      // The backend will handle the 30-day grace period and permanent deletion
      await repository.updateProfile(userId, {
        'deleted_at': deletedAt,
      });

      debugPrint('[AccountDeletion] updateProfile completed successfully');
      state = state.copyWith(
        isDeleting: false,
        isDeleted: true,
      );
      debugPrint('[AccountDeletion] State updated to isDeleted=true');
    } catch (e, stack) {
      debugPrint('[AccountDeletion] Error caught: $e');
      debugPrint('[AccountDeletion] Stack: $stack');
      state = state.copyWith(
        isDeleting: false,
        error: _getErrorMessage(e),
      );
      debugPrint(
          '[AccountDeletion] State updated with error: ${_getErrorMessage(e)}');
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();

    if (message.contains('network') || message.contains('connection')) {
      return 'Errore di connessione. Verifica la tua connessione internet.';
    }

    if (message.contains('offline')) {
      return 'Sei offline. Connettiti a internet per eliminare l\'account.';
    }

    return 'Errore nell\'eliminare l\'account. Riprova più tardi.';
  }

  /// Clear state
  void clearState() {
    state = const AccountDeletionState();
  }
}

/// Provider for account deletion
final accountDeletionProvider =
    StateNotifierProvider<AccountDeletionNotifier, AccountDeletionState>((ref) {
  return AccountDeletionNotifier(ref);
});
