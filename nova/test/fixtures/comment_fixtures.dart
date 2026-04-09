/// Comment test fixtures
///
/// Reusable test data for comment-related tests.

import 'package:nova/features/comments/domain/entities/comment.dart';
import 'test_fixtures.dart';

/// Test comment fixtures
class TestComments {
  static Comment topLevel({
    String? id,
    String? eventId,
    String? userId,
    String? text,
    DateTime? createdAt,
  }) {
    return Comment(
      id: id ?? 'comment-001',
      eventId: eventId ?? 'test-event-001',
      userId: userId ?? TestUserIds.student1,
      text: text ?? 'Bellissimo evento!',
      likeCount: 5,
      replyCount: 2,
      reportCount: 0,
      createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 1)),
      authorName: 'Mario Rossi',
      authorAvatarUrl: 'https://example.com/avatar.jpg',
      authorClass: '4A',
      authorRole: 'student',
    );
  }

  static Comment reply({
    String? parentCommentId,
    int depth = 1,
  }) {
    return Comment(
      id: 'comment-reply-001',
      eventId: 'test-event-001',
      userId: TestUserIds.student2,
      parentCommentId: parentCommentId ?? 'comment-001',
      depth: depth,
      text: 'Concordo!',
      likeCount: 1,
      replyCount: 0,
      reportCount: 0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      authorName: 'Lucia Bianchi',
      authorClass: '3B',
      authorRole: 'student',
    );
  }

  static Comment deleted() {
    return Comment(
      id: 'comment-deleted-001',
      eventId: 'test-event-001',
      userId: TestUserIds.student1,
      text: 'Testo originale',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      deletedAt: DateTime.now(),
      deletedByUserId: TestUserIds.student1,
      authorName: 'Mario Rossi',
      authorRole: 'student',
    );
  }

  static Comment hidden() {
    return Comment(
      id: 'comment-hidden-001',
      eventId: 'test-event-001',
      userId: TestUserIds.student1,
      text: 'Contenuto inappropriato',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      hiddenAt: DateTime.now(),
      hiddenReason: 'Violazione regolamento',
      moderatorId: TestUserIds.moderator,
      authorName: 'Mario Rossi',
      authorRole: 'student',
    );
  }

  static Comment maxDepthReply() {
    return Comment(
      id: 'comment-maxdepth-001',
      eventId: 'test-event-001',
      userId: TestUserIds.student1,
      parentCommentId: 'comment-depth2',
      depth: Comment.maxDepth,
      text: 'Reply al livello massimo',
      createdAt: DateTime.now(),
      authorName: 'Mario Rossi',
      authorRole: 'student',
    );
  }

  static Comment moderatorComment() {
    return Comment(
      id: 'comment-mod-001',
      eventId: 'test-event-001',
      userId: TestUserIds.moderator,
      text: 'Commento ufficiale del moderatore',
      createdAt: DateTime.now(),
      authorName: 'Prof Moderatore',
      authorRole: 'moderator',
    );
  }

  static List<Comment> sampleThread({int count = 5}) {
    return List.generate(count, (i) => topLevel(
      id: 'comment-$i',
      text: 'Commento $i',
      createdAt: DateTime.now().subtract(Duration(hours: count - i)),
    ));
  }

  TestComments._();
}
