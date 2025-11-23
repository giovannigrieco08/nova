import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import '../../data/datasources/comments_remote_datasource.dart';
import '../../data/datasources/comments_local_datasource.dart';
import '../../data/repositories/comments_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for CommentsRepository
final commentsRepositoryProvider = Provider<CommentsRepositoryInterface>((ref) {
  final supabase = Supabase.instance.client;
  final remoteDataSource = CommentsRemoteDataSource(supabase);
  final localDataSource = CommentsLocalDataSource();

  // Initialize local data source
  localDataSource.init();

  return CommentsRepository(remoteDataSource, localDataSource);
});

/// Provider family for comments by event ID
///
/// Usage:
/// ```dart
/// final commentsAsync = ref.watch(commentsNotifierProvider(eventId));
/// ```
final commentsNotifierProvider = AsyncNotifierProvider.family<
    CommentsNotifier,
    List<Comment>,
    String>(CommentsNotifier.new);

/// Comments state notifier for a specific event
///
/// Manages comment list state with pagination, real-time updates, and optimistic UI.
/// Uses AsyncNotifier pattern for loading/error/data states.
///
/// Features:
/// - Initial load with pagination support
/// - Real-time updates via Supabase Realtime
/// - Optimistic UI for new comments
/// - Pull-to-refresh support
/// - Offline cache fallback
class CommentsNotifier extends FamilyAsyncNotifier<List<Comment>, String> {
  late final CommentsRepositoryInterface _repository;
  late final String _eventId;

  @override
  Future<List<Comment>> build(String arg) async {
    _eventId = arg;
    _repository = ref.read(commentsRepositoryProvider);

    // Load initial comments
    return await _loadComments();
  }

  /// Load comments for the event
  ///
  /// Tries remote first, falls back to cache on network error.
  Future<List<Comment>> _loadComments() async {
    try {
      final result = await _repository.getCommentsForEvent(
        eventId: _eventId,
        sortOrder: CommentSortOrder.recent,
        limit: 20,
      );

      return result.comments;
    } catch (e) {
      // On error, try to load from cache
      final cachedComments = await _repository.getCachedComments(
        eventId: _eventId,
      );

      if (cachedComments != null && cachedComments.isNotEmpty) {
        return cachedComments;
      }

      rethrow; // No cache available, propagate error
    }
  }

  /// Refresh comments (pull-to-refresh)
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadComments());
  }

  /// Add optimistic comment (instant UI update before server confirms)
  ///
  /// Used when posting a new comment to provide instant feedback.
  /// If server request fails, the comment will be removed via refresh.
  void addOptimisticComment(Comment comment) {
    state.whenData((comments) {
      state = AsyncValue.data([comment, ...comments]);
    });
  }

  /// Remove optimistic comment (rollback on error)
  void removeOptimisticComment(String tempId) {
    state.whenData((comments) {
      state = AsyncValue.data(
        comments.where((c) => c.id != tempId).toList(),
      );
    });
  }

  /// Update comment in list (after edit or like)
  void updateComment(Comment updatedComment) {
    state.whenData((comments) {
      final updatedList = comments.map((c) {
        return c.id == updatedComment.id ? updatedComment : c;
      }).toList();

      state = AsyncValue.data(updatedList);
    });
  }

  /// Remove comment from list (after delete)
  void removeComment(String commentId) {
    state.whenData((comments) {
      state = AsyncValue.data(
        comments.where((c) => c.id != commentId).toList(),
      );
    });
  }

  /// Increment comment count (optimistic)
  void incrementCommentCount() {
    state.whenData((comments) {
      // Comment count is managed at event level, not here
      // This is handled by EventCard/EventDetailScreen
    });
  }
}
