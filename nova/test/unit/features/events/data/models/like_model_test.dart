import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/like_model.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('LikeModel', () {
    // =====================================================================
    // Happy Path Tests (H:2)
    // =====================================================================

    test('should create LikeModel with required fields', () {
      final like = LikeModel(
        userId: 'user-001',
        eventId: 'event-001',
        createdAt: now,
      );

      expect(like.userId, 'user-001');
      expect(like.eventId, 'event-001');
      expect(like.createdAt, now);
    });

    test('factory create sets createdAt to now', () {
      final like = LikeModel.create(
        userId: 'user-001',
        eventId: 'event-001',
      );

      expect(like.userId, 'user-001');
      expect(like.eventId, 'event-001');
      expect(like.createdAt, isNotNull);
    });

    // =====================================================================
    // Edge Case Tests (E:2)
    // =====================================================================

    test('equality is based on userId and eventId composite', () {
      final like1 = LikeModel(userId: 'u1', eventId: 'e1', createdAt: now);
      final like2 = LikeModel(
        userId: 'u1',
        eventId: 'e1',
        createdAt: now.add(const Duration(hours: 5)),
      );
      final like3 = LikeModel(userId: 'u1', eventId: 'e2', createdAt: now);
      final like4 = LikeModel(userId: 'u2', eventId: 'e1', createdAt: now);

      expect(like1, equals(like2));
      expect(like1.hashCode, like2.hashCode);
      expect(like1, isNot(equals(like3)));
      expect(like1, isNot(equals(like4)));
    });

    test('toString contains userId and eventId', () {
      final like = LikeModel(userId: 'u1', eventId: 'e1', createdAt: now);
      final str = like.toString();

      expect(str, contains('u1'));
      expect(str, contains('e1'));
    });
  });
}
