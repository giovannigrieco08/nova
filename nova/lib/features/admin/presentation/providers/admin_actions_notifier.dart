// =====================================================================
// Admin Actions Notifier - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Handle admin actions (promote/remove moderators)
// Architecture: Riverpod AsyncNotifier with error handling
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';

/// State for admin actions
class AdminActionsState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const AdminActionsState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AdminActionsState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return AdminActionsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Notifier for admin actions
///
/// Handles promoting users to moderator and removing moderator roles.
/// Updates moderatorsProvider automatically via database triggers.
class AdminActionsNotifier extends AutoDisposeNotifier<AdminActionsState> {
  @override
  AdminActionsState build() {
    return const AdminActionsState();
  }

  /// Promote user to moderator
  ///
  /// Calls promote_to_moderator() RPC function which:
  /// - Creates user_roles entry
  /// - Restores archived statistics
  /// - Logs action to admin_log
  /// - Creates notification for user
  Future<void> promoteUser(String userId, String userName) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final repository = ref.read(adminRepositoryProvider);
      await repository.promoteToModerator(userId);

      state = state.copyWith(
        isLoading: false,
        successMessage: '$userName è stato promosso a moderatore.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante la promozione: $e',
      );
    }
  }

  /// Remove moderator role
  ///
  /// Calls remove_moderator_role() RPC function which:
  /// - Deletes user_roles entry
  /// - Archives current statistics
  /// - Logs action to admin_log
  /// - Creates notification for user
  Future<void> removeUser(String userId, String userName) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final repository = ref.read(adminRepositoryProvider);
      await repository.removeModerator(userId);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Il ruolo di moderatore è stato rimosso da $userName.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante la rimozione: $e',
      );
    }
  }

  /// Clear error and success messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

/// Provider for admin actions notifier
final adminActionsNotifierProvider =
    NotifierProvider.autoDispose<AdminActionsNotifier, AdminActionsState>(
  AdminActionsNotifier.new,
);
