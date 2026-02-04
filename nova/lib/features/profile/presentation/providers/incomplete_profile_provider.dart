// Provider: IncompleteProfileProvider
// Feature: 002-profile-setup
// Purpose: Manage incomplete profile state and banner visibility

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/profile.dart';
import 'profile_provider.dart';

/// Provider to check if current user's profile is incomplete
final isProfileIncompleteProvider = Provider<AsyncValue<bool>>((ref) {
  final profileAsync = ref.watch(currentProfileProvider);

  return profileAsync.when(
    data: (profile) {
      // Profile is incomplete if class is null or empty
      final isIncomplete = !profile.isComplete;
      return AsyncValue.data(isIncomplete);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Banner dismissal state provider
///
/// Manages whether the incomplete profile banner has been dismissed
/// Persisted using SharedPreferences
class BannerDismissalNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const String _key = 'incomplete_profile_banner_dismissed';

  BannerDismissalNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  /// Dismiss the banner (hide for this session)
  Future<void> dismiss() async {
    await _prefs.setBool(_key, true);
    state = true;
  }

  /// Reset dismissal (show banner again)
  Future<void> reset() async {
    await _prefs.setBool(_key, false);
    state = false;
  }
}

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with actual instance',
  );
});

/// Banner dismissal provider
final bannerDismissalProvider =
    StateNotifierProvider<BannerDismissalNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BannerDismissalNotifier(prefs);
});

/// Combined provider: Show banner if profile incomplete AND not dismissed
final showIncompleteBannerProvider = Provider<AsyncValue<bool>>((ref) {
  final isIncompleteAsync = ref.watch(isProfileIncompleteProvider);
  final isDismissed = ref.watch(bannerDismissalProvider);

  return isIncompleteAsync.when(
    data: (isIncomplete) {
      // Show banner if profile is incomplete AND not dismissed
      final shouldShow = isIncomplete && !isDismissed;
      return AsyncValue.data(shouldShow);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
