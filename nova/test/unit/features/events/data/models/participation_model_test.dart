import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/participation_model.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('ParticipationModel', () {
    // =====================================================================
    // Happy Path Tests (H:2)
    // =====================================================================

    test('should create ParticipationModel with required fields', () {
      final participation = ParticipationModel(
        userId: 'user-001',
        eventId: 'event-001',
        createdAt: now,
      );

      expect(participation.userId, 'user-001');
      expect(participation.eventId, 'event-001');
      expect(participation.createdAt, now);
    });

    test('factory create sets createdAt to now', () {
      final participation = ParticipationModel.create(
        userId: 'user-001',
        eventId: 'event-001',
      );

      expect(participation.userId, 'user-001');
      expect(participation.eventId, 'event-001');
      expect(participation.createdAt, isNotNull);
    });

    // =====================================================================
    // Edge Case Tests (E:2)
    // =====================================================================

    test('equality is based on userId and eventId composite', () {
      final p1 = ParticipationModel(userId: 'u1', eventId: 'e1', createdAt: now);
      final p2 = ParticipationModel(
        userId: 'u1',
        eventId: 'e1',
        createdAt: now.add(const Duration(days: 1)),
      );
      final p3 = ParticipationModel(userId: 'u2', eventId: 'e1', createdAt: now);
      final p4 = ParticipationModel(userId: 'u1', eventId: 'e2', createdAt: now);

      expect(p1, equals(p2));
      expect(p1.hashCode, p2.hashCode);
      expect(p1, isNot(equals(p3)));
      expect(p1, isNot(equals(p4)));
    });

    test('toString contains userId and eventId', () {
      final p = ParticipationModel(userId: 'u1', eventId: 'e1', createdAt: now);
      final str = p.toString();

      expect(str, contains('u1'));
      expect(str, contains('e1'));
    });
  });
}
