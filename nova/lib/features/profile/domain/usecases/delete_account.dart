// Usecase: DeleteAccount
// Feature: 006-user-profile (User Story 3 - T058)
// Purpose: GDPR Right to Erasure - soft delete account with 30-day grace period

import '../../data/repositories/gdpr_repository.dart';

/// Delete account usecase (GDPR Article 17: Right to Erasure)
///
/// **Flow**:
/// 1. User taps "Elimina account" in Settings → Privacy
/// 2. Shows AlertDialog: "Sei sicuro? Account eliminato dopo 30 giorni. Puoi annullare entro 30 giorni."
/// 3. User confirms → calls this usecase
/// 4. Sets deleted_at = NOW() in profiles table
/// 5. Shows banner: "Account eliminato. Hai 30 giorni per annullare."
/// 6. Profile hidden to other users immediately (RLS policy)
/// 7. After 30 days, cron job hard-deletes account and avatar
///
/// **Success Criteria**:
/// - Profile immediately hidden to other users
/// - User can still login and see reactivation option
/// - Soft delete reversible within 30 days via ReactivateAccount usecase
///
/// **Usage**:
/// ```dart
/// final deleteAccount = ref.read(deleteAccountUseCaseProvider);
/// await deleteAccount(userId);
///
/// // Show confirmation banner
/// showBanner('Account eliminato. Hai 30 giorni per annullare.');
/// ```
class DeleteAccount {
  final GDPRRepository _repository;

  DeleteAccount(this._repository);

  /// Soft delete account (sets deleted_at = NOW())
  ///
  /// **Input**: User ID (UUID)
  /// **Output**: void
  ///
  /// **Effects**:
  /// - Profile hidden to other users immediately
  /// - User can login and reactivate within 30 days
  /// - After 30 days, hard-deleted by cron job
  ///
  /// **Throws**: Exception if soft delete fails
  Future<void> call(String userId) async {
    return await _repository.softDeleteAccount(userId);
  }
}

/// Reactivate account usecase (undo soft delete within 30 days)
///
/// **Flow**:
/// 1. User logs in after soft deletion
/// 2. Shows dialog: "Vuoi riattivare il tuo account?"
/// 3. User confirms → calls this usecase
/// 4. Sets deleted_at = NULL
/// 5. Profile visible again if profile_visible = true
///
/// **Success Criteria**:
/// - Reactivation only allowed within 30 days
/// - Profile restored to previous state
///
/// **Usage**:
/// ```dart
/// final reactivateAccount = ref.read(reactivateAccountUseCaseProvider);
/// await reactivateAccount(userId);
///
/// // Show success toast
/// showToast('Account riattivato!');
/// ```
class ReactivateAccount {
  final GDPRRepository _repository;

  ReactivateAccount(this._repository);

  /// Reactivate soft-deleted account (sets deleted_at = NULL)
  ///
  /// **Input**: User ID (UUID)
  /// **Output**: void
  ///
  /// **Condition**: deleted_at must be within 30 days
  ///
  /// **Throws**: Exception if >30 days passed or reactivation fails
  Future<void> call(String userId) async {
    return await _repository.reactivateAccount(userId);
  }
}
