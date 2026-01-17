// Provider: GDPRExportProvider
// Feature: 006-user-profile (US3 - GDPR Compliance)
// Purpose: Handles GDPR data export and account deletion functionality

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  GDPRExportMetadata? get metadata => downloadUrl != null ? GDPRExportMetadata(downloadUrl: downloadUrl!) : null;
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
      // TODO(T065): Implement actual GDPR export via Supabase Edge Function
      await Future.delayed(const Duration(seconds: 2)); // Simulate

      // In real implementation, this would be:
      // 1. Call Supabase Edge Function `export-user-data`
      // 2. Wait for signed URL response
      // 3. Return download URL

      state = state.copyWith(
        isExporting: false,
        downloadUrl: 'https://example.com/export.json', // Placeholder
      );
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        error: e.toString(),
      );
    }
  }

  /// Clear export state
  void clearState() {
    state = const GDPRExportState();
  }
}

/// Provider for GDPR export functionality
final gdprExportProvider = StateNotifierProvider<GDPRExportNotifier, GDPRExportState>((ref) {
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
    state = state.copyWith(isDeleting: true, error: null);

    try {
      // Get the profile repository
      final repository = _ref.read(profileRepositoryProvider);

      // Set deleted_at timestamp for soft delete
      // The backend will handle the 30-day grace period and permanent deletion
      await repository.updateProfile(userId, {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      });

      state = state.copyWith(
        isDeleting: false,
        isDeleted: true,
      );
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        error: _getErrorMessage(e),
      );
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
final accountDeletionProvider = StateNotifierProvider<AccountDeletionNotifier, AccountDeletionState>((ref) {
  return AccountDeletionNotifier(ref);
});
