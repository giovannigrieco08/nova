import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment.dart';
import '../../domain/usecases/get_replies_for_comment.dart';
import '../../data/repositories/comments_repository.dart';

/// RepliesProvider - Fetches replies for a specific comment
///
/// Uses GetRepliesForComment use case to load all replies for a parent comment.
/// Returns list sorted by created_at ascending (oldest first).
///
/// **FR-031**: Students can reply to comments (1-level threading)
/// **FR-032**: Replies display indented under parent comment
///
/// Usage:
/// ```dart
/// final repliesAsync = ref.watch(repliesProviderFamily(parentCommentId));
/// repliesAsync.when(
///   data: (replies) => ListView(children: replies.map(...)),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(error: err),
/// );
/// ```
final repliesProviderFamily = FutureProvider.family<List<Comment>, String>(
  (ref, parentCommentId) async {
    final repository = ref.read(commentsRepositoryProvider);
    final getReplies = GetRepliesForComment(repository);

    return await getReplies(commentId: parentCommentId);
  },
);
