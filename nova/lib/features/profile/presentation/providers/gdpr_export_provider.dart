// Provider: GDPRExportProvider
// Feature: 006-user-profile (User Story 3 - T060)
// Purpose: Manages GDPR export generation state with loading/success/error states

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/gdpr_export_datasource.dart';
import '../../data/repositories/gdpr_repository.dart';
import '../../data/models/gdpr_export_model.dart';
import '../../domain/usecases/export_user_data.dart';
import '../../domain/usecases/delete_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// GDPR datasource provider
final gdprExportDatasourceProvider = Provider<GDPRExportDatasource>((ref) {
  return GDPRExportDatasource(Supabase.instance.client);
});

/// GDPR repository provider
final gdprRepositoryProvider = Provider<GDPRRepository>((ref) {
  final datasource = ref.watch(gdprExportDatasourceProvider);
  return GDPRRepository(datasource);
});

/// Export user data usecase provider
final exportUserDataUseCaseProvider = Provider<ExportUserData>((ref) {
  final repository = ref.watch(gdprRepositoryProvider);
  return ExportUserData(repository);
});

/// Delete account usecase provider
final deleteAccountUseCaseProvider = Provider<DeleteAccount>((ref) {
  final repository = ref.watch(gdprRepositoryProvider);
  return DeleteAccount(repository);
});

/// Reactivate account usecase provider
final reactivateAccountUseCaseProvider = Provider<ReactivateAccount>((ref) {
  final repository = ref.watch(gdprRepositoryProvider);
  return ReactivateAccount(repository);
});

// ============================================================================
// GDPR EXPORT STATE MANAGEMENT
// ============================================================================

/// GDPR export state
///
/// **States**:
/// - idle: No export in progress
/// - loading: Export generation in progress
/// - success: Export complete, download URL available
/// - error: Export failed with error message
class GDPRExportState {
  final bool isLoading;
  final GDPRExportMetadata? metadata;
  final String? errorMessage;

  const GDPRExportState({
    this.isLoading = false,
    this.metadata,
    this.errorMessage,
  });

  bool get isIdle => !isLoading && metadata == null && errorMessage == null;
  bool get isSuccess => metadata != null;
  bool get isError => errorMessage != null;

  GDPRExportState copyWith({
    bool? isLoading,
    GDPRExportMetadata? metadata,
    String? errorMessage,
  }) {
    return GDPRExportState(
      isLoading: isLoading ?? this.isLoading,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  GDPRExportState clear() {
    return const GDPRExportState();
  }
}

/// GDPR export provider
///
/// **Usage**:
/// ```dart
/// final exportNotifier = ref.read(gdprExportProvider.notifier);
///
/// // Trigger export
/// await exportNotifier.exportUserData(userId);
///
/// // Watch state
/// final exportState = ref.watch(gdprExportProvider);
/// if (exportState.isLoading) {
///   return CircularProgressIndicator();
/// } else if (exportState.isSuccess) {
///   return Text('Download: ${exportState.metadata!.downloadUrl}');
/// }
/// ```
final gdprExportProvider =
    StateNotifierProvider<GDPRExportNotifier, GDPRExportState>((ref) {
  final exportUseCase = ref.watch(exportUserDataUseCaseProvider);
  return GDPRExportNotifier(exportUseCase);
});

/// GDPR export notifier (manages export state)
class GDPRExportNotifier extends StateNotifier<GDPRExportState> {
  final ExportUserData _exportUserData;

  GDPRExportNotifier(this._exportUserData)
      : super(const GDPRExportState());

  /// Export user data
  ///
  /// **Flow**:
  /// 1. Set state to loading
  /// 2. Call Edge Function export-user-data
  /// 3. On success: Set metadata with download URL
  /// 4. On error: Set error message
  ///
  /// **Success**: State contains GDPRExportMetadata with download URL (24h expiry)
  /// **Error**: State contains error message
  Future<void> exportUserData(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final metadata = await _exportUserData(userId);

      state = state.copyWith(
        isLoading: false,
        metadata: metadata,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore nella generazione dei dati: ${e.toString()}',
      );
    }
  }

  /// Clear export state
  void clear() {
    state = state.clear();
  }
}

// ============================================================================
// ACCOUNT DELETION STATE MANAGEMENT
// ============================================================================

/// Account deletion state
class AccountDeletionState {
  final bool isDeleting;
  final bool isReactivating;
  final bool isDeleted;
  final bool isReactivated;
  final String? errorMessage;

  const AccountDeletionState({
    this.isDeleting = false,
    this.isReactivating = false,
    this.isDeleted = false,
    this.isReactivated = false,
    this.errorMessage,
  });

  bool get isBusy => isDeleting || isReactivating;

  AccountDeletionState copyWith({
    bool? isDeleting,
    bool? isReactivating,
    bool? isDeleted,
    bool? isReactivated,
    String? errorMessage,
  }) {
    return AccountDeletionState(
      isDeleting: isDeleting ?? this.isDeleting,
      isReactivating: isReactivating ?? this.isReactivating,
      isDeleted: isDeleted ?? this.isDeleted,
      isReactivated: isReactivated ?? this.isReactivated,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  AccountDeletionState clear() {
    return const AccountDeletionState();
  }
}

/// Account deletion provider
///
/// **Usage**:
/// ```dart
/// final deleteNotifier = ref.read(accountDeletionProvider.notifier);
///
/// // Soft delete account
/// await deleteNotifier.softDeleteAccount(userId);
///
/// // Reactivate account (within 30 days)
/// await deleteNotifier.reactivateAccount(userId);
/// ```
final accountDeletionProvider =
    StateNotifierProvider<AccountDeletionNotifier, AccountDeletionState>((ref) {
  final deleteUseCase = ref.watch(deleteAccountUseCaseProvider);
  final reactivateUseCase = ref.watch(reactivateAccountUseCaseProvider);
  return AccountDeletionNotifier(deleteUseCase, reactivateUseCase);
});

/// Account deletion notifier
class AccountDeletionNotifier extends StateNotifier<AccountDeletionState> {
  final DeleteAccount _deleteAccount;
  final ReactivateAccount _reactivateAccount;

  AccountDeletionNotifier(this._deleteAccount, this._reactivateAccount)
      : super(const AccountDeletionState());

  /// Soft delete account (set deleted_at = NOW())
  ///
  /// **Success**: State.isDeleted = true
  /// **Error**: State.errorMessage set
  Future<void> softDeleteAccount(String userId) async {
    state = state.copyWith(isDeleting: true, errorMessage: null);

    try {
      await _deleteAccount(userId);

      state = state.copyWith(
        isDeleting: false,
        isDeleted: true,
      );
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: 'Errore nell\'eliminazione dell\'account: ${e.toString()}',
      );
    }
  }

  /// Reactivate soft-deleted account (set deleted_at = NULL)
  ///
  /// **Condition**: deleted_at must be within 30 days
  /// **Success**: State.isReactivated = true
  /// **Error**: State.errorMessage set
  Future<void> reactivateAccount(String userId) async {
    state = state.copyWith(isReactivating: true, errorMessage: null);

    try {
      await _reactivateAccount(userId);

      state = state.copyWith(
        isReactivating: false,
        isReactivated: true,
      );
    } catch (e) {
      state = state.copyWith(
        isReactivating: false,
        errorMessage: 'Errore nella riattivazione dell\'account: ${e.toString()}',
      );
    }
  }

  /// Clear state
  void clear() {
    state = state.clear();
  }
}
