import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import '../../data/providers/comments_data_providers.dart';
export '../../data/providers/comments_data_providers.dart' show commentsRepositoryProvider;
// UGC Safety: Block filtering (T046)
import '../../../safety/presentation/providers/block_provider.dart';

/// Provider family for comments by event ID
///
/// Usage:
/// ```dart
/// final commentsAsync = ref.watch(commentsNotifierProvider(eventId));
/// ```
final commentsNotifierProvider =
    AsyncNotifierProvider.family<CommentsNotifier, CommentsState, String>(
        CommentsNotifier.new);

/// Paginated comments state
///
/// **T094**: Pagination state management with hasMore, nextCursor, loading indicator
/// **T099**: Sort state management with sortOrder enum
class CommentsState {
  final List<Comment> comments;
  final bool hasMore;
  final DateTime? nextCursor;
  final bool isLoadingMore;
  final bool isRefreshing;
  final CommentSortOrder sortOrder;
  final bool isSorting; // T103: Loading indicator during re-sort

  const CommentsState({
    required this.comments,
    this.hasMore = true,
    this.nextCursor,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.sortOrder = CommentSortOrder.recent,
    this.isSorting = false,
  });

  CommentsState copyWith({
    List<Comment>? comments,
    bool? hasMore,
    DateTime? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    bool? isRefreshing,
    CommentSortOrder? sortOrder,
    bool? isSorting,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      sortOrder: sortOrder ?? this.sortOrder,
      isSorting: isSorting ?? this.isSorting,
    );
  }

  /// Total comment count for display
  int get totalCount => comments.length;

  /// Check if list is empty
  bool get isEmpty => comments.isEmpty;

  /// Initial empty state
  static const empty = CommentsState(comments: [], hasMore: true);
}

/// Comments state notifier for a specific event
///
/// Manages comment list state with pagination, real-time updates, and optimistic UI.
/// Uses AsyncNotifier pattern for loading/error/data states.
///
/// **T092**: Cursor-based pagination with cursorCreatedAt parameter
/// **T094**: Pagination state management (hasMore, nextCursor, isLoadingMore)
/// **T095**: Handle end-of-list (hasMore == false)
/// **T096**: Pull-to-refresh with cache clearing
/// **T099**: Sort state management
/// **T100**: Sort order parameter for queries
/// **T102**: Sort toggle handler
///
/// Features:
/// - Initial load with pagination support (20 per page)
/// - Real-time updates via Supabase Realtime
/// - Optimistic UI for new comments
/// - Pull-to-refresh support
/// - Offline cache fallback
/// - Infinite scroll with cursor-based pagination
/// - Toggle between "Recenti" and "Popolari" sorting
class CommentsNotifier extends FamilyAsyncNotifier<CommentsState, String> {
  late final CommentsRepositoryInterface _repository;
  late final String _eventId;

  /// Current sort order (persisted across refreshes)
  CommentSortOrder _sortOrder = CommentSortOrder.recent;

  /// Page size for pagination
  static const int _pageSize = 20;

  @override
  Future<CommentsState> build(String arg) async {
    _eventId = arg;
    _repository = ref.read(commentsRepositoryProvider);

    // Load initial comments
    return await _loadInitialComments();
  }

  /// Load initial page of comments
  ///
  /// Tries remote first, falls back to cache on network error.
  /// **T100**: Uses current sortOrder for query
  /// **T046**: Filters out comments from blocked users
  Future<CommentsState> _loadInitialComments() async {
    try {
      final result = await _repository.getCommentsForEvent(
        eventId: _eventId,
        sortOrder: _sortOrder,
        limit: _pageSize,
      );

      // UGC Safety: Filter out comments from blocked users (T046)
      var filteredComments = result.comments;
      try {
        final blockedUserIds = await ref.read(blockedUserIdsProvider.future);
        if (blockedUserIds.isNotEmpty) {
          filteredComments = result.comments
              .where((c) => !blockedUserIds.contains(c.userId))
              .toList();
        }
      } catch (_) {
        // Silently fail if block list unavailable
      }

      // Cache comments for offline access
      if (filteredComments.isNotEmpty) {
        await _repository.cacheComments(
          eventId: _eventId,
          comments: filteredComments,
        );
      }

      return CommentsState(
        comments: filteredComments,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        sortOrder: _sortOrder,
      );
    } catch (e) {
      // On error, try to load from cache
      final cachedComments = await _repository.getCachedComments(
        eventId: _eventId,
      );

      if (cachedComments != null && cachedComments.isNotEmpty) {
        return CommentsState(
          comments: cachedComments,
          hasMore: false, // Can't paginate offline
          nextCursor: null,
          sortOrder: _sortOrder,
        );
      }

      rethrow; // No cache available, propagate error
    }
  }

  /// Load next page of comments (infinite scroll)
  ///
  /// **T092**: Implements cursor-based pagination
  /// **T093**: Called when scroll reaches 80% threshold
  /// **T095**: Stops when hasMore == false
  /// **T100**: Uses current sortOrder
  Future<void> loadMore() async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    // T095: Don't load more if no more pages or already loading
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    // Set loading state
    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final result = await _repository.getCommentsForEvent(
        eventId: _eventId,
        sortOrder: _sortOrder,
        limit: _pageSize,
        cursorCreatedAt: currentState.nextCursor,
      );

      // UGC Safety: Filter out comments from blocked users (T046)
      var filteredNewComments = result.comments;
      try {
        final blockedUserIds = await ref.read(blockedUserIdsProvider.future);
        if (blockedUserIds.isNotEmpty) {
          filteredNewComments = result.comments
              .where((c) => !blockedUserIds.contains(c.userId))
              .toList();
        }
      } catch (_) {
        // Silently fail if block list unavailable
      }

      // Append new comments to existing list
      final updatedComments = [
        ...currentState.comments,
        ...filteredNewComments
      ];

      // Update cache with full list
      await _repository.cacheComments(
        eventId: _eventId,
        comments: updatedComments,
      );

      state = AsyncValue.data(CommentsState(
        comments: updatedComments,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        isLoadingMore: false,
        sortOrder: _sortOrder,
      ));
    } catch (e) {
      // Reset loading state on error, keep existing comments
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
    }
  }

  /// Change sort order and reload comments
  ///
  /// **T102**: Sort toggle handler
  /// - Updates sortOrder state
  /// - Re-fetches comments with new order
  /// - Resets scroll position via state change
  /// **T103**: Shows loading indicator during re-sort
  Future<void> changeSortOrder(CommentSortOrder newOrder) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    // Don't reload if same order
    if (newOrder == _sortOrder) return;

    // Update internal sort order
    _sortOrder = newOrder;

    // T103: Show sorting loading indicator
    state = AsyncValue.data(currentState.copyWith(
      isSorting: true,
      sortOrder: newOrder,
    ));

    try {
      // Reload first page with new sort order
      final result = await _repository.getCommentsForEvent(
        eventId: _eventId,
        sortOrder: _sortOrder,
        limit: _pageSize,
      );

      state = AsyncValue.data(CommentsState(
        comments: result.comments,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        sortOrder: _sortOrder,
        isSorting: false,
      ));
    } catch (e) {
      // Revert sort order on error
      _sortOrder = currentState.sortOrder;
      state = AsyncValue.data(currentState.copyWith(
        isSorting: false,
        sortOrder: currentState.sortOrder,
      ));
    }
  }

  /// Refresh comments (pull-to-refresh)
  ///
  /// **T096**: Clears local cache, re-fetches first page,
  /// merges with realtime updates
  Future<void> refresh() async {
    final currentState = state.valueOrNull;

    // Show refreshing state while keeping existing data visible
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(isRefreshing: true));
    } else {
      state = const AsyncValue.loading();
    }

    try {
      // Reload first page (clears pagination state)
      final newState = await _loadInitialComments();
      state = AsyncValue.data(newState);
    } catch (e, stack) {
      if (currentState != null) {
        // Keep existing data on error, just clear refreshing state
        state = AsyncValue.data(currentState.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  /// Add optimistic comment (instant UI update before server confirms)
  ///
  /// Used when posting a new comment to provide instant feedback.
  /// If server request fails, the comment will be removed via refresh.
  void addOptimisticComment(Comment comment) {
    state.whenData((currentState) {
      state = AsyncValue.data(currentState.copyWith(
        comments: [comment, ...currentState.comments],
      ));
    });
  }

  /// Remove optimistic comment (rollback on error)
  void removeOptimisticComment(String tempId) {
    state.whenData((currentState) {
      state = AsyncValue.data(currentState.copyWith(
        comments: currentState.comments.where((c) => c.id != tempId).toList(),
      ));
    });
  }

  /// Update comment in list (after edit or like)
  void updateComment(Comment updatedComment) {
    state.whenData((currentState) {
      final updatedList = currentState.comments.map((c) {
        return c.id == updatedComment.id ? updatedComment : c;
      }).toList();

      state = AsyncValue.data(currentState.copyWith(comments: updatedList));
    });
  }

  /// Remove comment from list (after delete)
  void removeComment(String commentId) {
    state.whenData((currentState) {
      state = AsyncValue.data(currentState.copyWith(
        comments:
            currentState.comments.where((c) => c.id != commentId).toList(),
      ));
    });
  }

  /// Replace all comments (used by realtime provider)
  void replaceComments(List<Comment> newComments) {
    state.whenData((currentState) {
      state = AsyncValue.data(currentState.copyWith(comments: newComments));
    });
  }

  /// Increment comment count (optimistic)
  void incrementCommentCount() {
    state.whenData((currentState) {
      // Comment count is managed at event level, not here
      // This is handled by EventCard/EventDetailScreen
    });
  }
}
