import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_block.dart';
import '../../data/repositories/block_repository.dart';
import '../../domain/services/block_service.dart';
// UGC Safety: Import for feed refresh on block/unblock (T081)
import '../../../events/presentation/providers/events_feed_provider.dart';

/// Provider for BlockRepository
final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository();
});

/// Provider for BlockService
final blockServiceProvider = Provider<BlockService>((ref) {
  return BlockService(
    repository: ref.watch(blockRepositoryProvider),
  );
});

/// State for block operations
class BlockState {
  const BlockState({
    this.isLoading = false,
    this.error,
    this.lastBlockedUserId,
    this.lastUnblockedUserId,
  });

  final bool isLoading;
  final String? error;
  final String? lastBlockedUserId;
  final String? lastUnblockedUserId;

  BlockState copyWith({
    bool? isLoading,
    String? error,
    String? lastBlockedUserId,
    String? lastUnblockedUserId,
  }) {
    return BlockState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastBlockedUserId: lastBlockedUserId ?? this.lastBlockedUserId,
      lastUnblockedUserId: lastUnblockedUserId ?? this.lastUnblockedUserId,
    );
  }
}

/// Notifier for managing block operations
class BlockNotifier extends StateNotifier<BlockState> {
  BlockNotifier(this._service, this._ref) : super(const BlockState());

  final BlockService _service;
  final Ref _ref;

  /// Block a user
  Future<bool> blockUser(String userId) async {
    debugPrint('[BlockNotifier] blockUser called for: $userId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.blockUser(userId);
      debugPrint('[BlockNotifier] Block successful');
      state = state.copyWith(
        isLoading: false,
        lastBlockedUserId: userId,
      );

      // Invalidate related providers
      _ref.invalidate(blockedUsersProvider);
      _ref.invalidate(isUserBlockedProvider(userId));
      _ref.invalidate(blockedUserIdsProvider);

      // UGC Safety: Immediately remove blocked user's content from feeds
      _ref.invalidate(eventsFeedProvider);
      // Note: chatMessagesStreamProvider will rebuild and re-filter on next access
      // Comments use family provider - they'll re-filter when blockedUserIdsProvider updates

      return true;
    } on UserAlreadyBlockedException {
      debugPrint('[BlockNotifier] User already blocked');
      state = state.copyWith(
        isLoading: false,
        error: 'Utente già bloccato',
      );
      return false;
    } catch (e, stack) {
      debugPrint('[BlockNotifier] Error: $e');
      debugPrint('[BlockNotifier] Stack: $stack');
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante il blocco: ${e.toString()}',
      );
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _service.unblockUser(userId);
      state = state.copyWith(
        isLoading: false,
        lastUnblockedUserId: userId,
      );

      // Invalidate related providers
      _ref.invalidate(blockedUsersProvider);
      _ref.invalidate(isUserBlockedProvider(userId));
      _ref.invalidate(blockedUserIdsProvider);

      // UGC Safety: Refresh events feed to show unblocked user's content (T081)
      _ref.invalidate(eventsFeedProvider);

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante lo sblocco: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset state
  void reset() {
    state = const BlockState();
  }
}

/// Provider for block operations state
final blockNotifierProvider =
    StateNotifierProvider<BlockNotifier, BlockState>((ref) {
  return BlockNotifier(ref.watch(blockServiceProvider), ref);
});

/// Provider for list of blocked users
final blockedUsersProvider = FutureProvider<List<UserBlock>>((ref) async {
  final service = ref.watch(blockServiceProvider);
  return service.getBlockedUsers();
});

/// Provider to check if a specific user is blocked
final isUserBlockedProvider = FutureProvider.family<bool, String>(
  (ref, userId) async {
    final service = ref.watch(blockServiceProvider);
    return service.isUserBlocked(userId);
  },
);

/// Provider to check if current user is blocked by another user
final isBlockedByUserProvider = FutureProvider.family<bool, String>(
  (ref, userId) async {
    final service = ref.watch(blockServiceProvider);
    return service.isBlockedByUser(userId);
  },
);

/// Provider for checking if current user can view a profile
final canViewProfileProvider = FutureProvider.family<bool, String>(
  (ref, userId) async {
    final service = ref.watch(blockServiceProvider);
    return service.canViewProfile(userId);
  },
);

/// Provider for list of blocked user IDs (for feed filtering)
final blockedUserIdsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(blockServiceProvider);
  return service.getBlockedUserIds();
});
