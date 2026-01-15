import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';
import '../../../../core/animations/page_transitions.dart';

/// MentionNavigationProvider
///
/// Handles @mention tap navigation to user profiles.
///
/// **T113**: Tap handler for @mentions - look up user_id, navigate to ProfileScreen
/// **T114**: Handle invalid mentions (user doesn't exist)
///
/// Flow:
/// 1. Receive username from tap
/// 2. Look up user_id from profiles table
/// 3. If found: navigate to OtherProfileScreen
/// 4. If not found: show "Profilo non trovato" toast
class MentionNavigationNotifier extends StateNotifier<MentionNavigationState> {
  MentionNavigationNotifier() : super(const MentionNavigationState());

  /// Navigate to profile by username
  ///
  /// **T113**: Look up user_id from profiles table, navigate to ProfileScreen
  /// **T114**: Handle invalid mentions with toast
  Future<MentionNavigationResult> navigateToProfile(
    BuildContext context,
    String username,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Look up user by username/name
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('id, full_name')
          .or('full_name.ilike.%$username%,username.eq.$username')
          .limit(1)
          .maybeSingle();

      if (response == null) {
        // T114: User not found
        state = state.copyWith(
          isLoading: false,
          error: 'Profilo non trovato',
        );
        return MentionNavigationResult.notFound;
      }

      final userId = response['id'] as String;

      // Navigate to profile
      if (context.mounted) {
        Navigator.push(
          context,
          NovaPageRoute.swipeBack(page: OtherProfileScreen(userId: userId)),
        );
      }

      state = state.copyWith(isLoading: false);
      return MentionNavigationResult.success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante la ricerca del profilo',
      );
      return MentionNavigationResult.error;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Mention navigation state
class MentionNavigationState {
  final bool isLoading;
  final String? error;

  const MentionNavigationState({
    this.isLoading = false,
    this.error,
  });

  MentionNavigationState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return MentionNavigationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Mention navigation result
enum MentionNavigationResult {
  success,
  notFound,
  error,
}

/// Provider for mention navigation
final mentionNavigationProvider =
    StateNotifierProvider<MentionNavigationNotifier, MentionNavigationState>(
  (ref) => MentionNavigationNotifier(),
);

/// Helper function to show mention navigation feedback
void showMentionNavigationFeedback(
  BuildContext context,
  MentionNavigationResult result,
) {
  if (result == MentionNavigationResult.success) return;

  final message = switch (result) {
    MentionNavigationResult.success => null,
    MentionNavigationResult.notFound => 'Profilo non trovato',
    MentionNavigationResult.error => 'Errore durante la ricerca del profilo',
  };

  if (message != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
