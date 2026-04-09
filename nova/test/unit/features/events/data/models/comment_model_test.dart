import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/comment_model.dart';
import 'package:nova/features/events/domain/entities/comment.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('CommentModel', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create CommentModel with required fields', () {
      final model = CommentModel(
        id: 'comment-001',
        eventId: 'event-001',
        authorId: 'user-001',
        content: 'Great event!',
        createdAt: now,
      );

      expect(model.id, 'comment-001');
      expect(model.eventId, 'event-001');
      expect(model.authorId, 'user-001');
      expect(model.content, 'Great event!');
      expect(model.authorData, isNull);
    });

    test('toEntity converts model to Comment entity with author data', () {
      final model = CommentModel(
        id: 'comment-001',
        eventId: 'event-001',
        authorId: 'user-001',
        content: 'Bellissimo evento!',
        createdAt: now,
        authorData: {
          'full_name': 'Mario Rossi',
          'avatar_url': 'https://example.com/avatar.jpg',
          'class': '4A',
        },
      );

      final entity = model.toEntity();

      expect(entity, isA<Comment>());
      expect(entity.id, 'comment-001');
      expect(entity.authorName, 'Mario Rossi');
      expect(entity.authorAvatarUrl, 'https://example.com/avatar.jpg');
      expect(entity.authorClass, '4A');
    });

    test('fromEntity creates model from domain Comment', () {
      final entity = Comment(
        id: 'comment-001',
        eventId: 'event-001',
        authorId: 'user-001',
        content: 'Bel lavoro!',
        createdAt: now,
        authorName: 'Mario',
      );

      final model = CommentModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.eventId, entity.eventId);
      expect(model.authorId, entity.authorId);
      expect(model.content, entity.content);
      expect(model.authorData, isNull); // fromEntity does not carry author join data
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('toEntity with null authorData sets author info to null', () {
      final model = CommentModel(
        id: 'c1',
        eventId: 'e1',
        authorId: 'u1',
        content: 'Test',
        createdAt: now,
        authorData: null,
      );

      final entity = model.toEntity();

      expect(entity.authorName, isNull);
      expect(entity.authorAvatarUrl, isNull);
      expect(entity.authorClass, isNull);
    });

    test('equality is based on id only', () {
      final m1 = CommentModel(
        id: 'c1', eventId: 'e1', authorId: 'u1',
        content: 'Text A', createdAt: now,
      );
      final m2 = CommentModel(
        id: 'c1', eventId: 'e2', authorId: 'u2',
        content: 'Text B', createdAt: now,
      );
      final m3 = CommentModel(
        id: 'c2', eventId: 'e1', authorId: 'u1',
        content: 'Text A', createdAt: now,
      );

      expect(m1, equals(m2));
      expect(m1.hashCode, m2.hashCode);
      expect(m1, isNot(equals(m3)));
    });

    test('copyWith preserves unmodified fields', () {
      final model = CommentModel(
        id: 'c1',
        eventId: 'e1',
        authorId: 'u1',
        content: 'Original',
        createdAt: now,
        authorData: {'full_name': 'Mario'},
      );

      final updated = model.copyWith(content: 'Updated text');

      expect(updated.content, 'Updated text');
      expect(updated.id, 'c1');
      expect(updated.eventId, 'e1');
      expect(updated.authorData, {'full_name': 'Mario'});
    });
  });
}
