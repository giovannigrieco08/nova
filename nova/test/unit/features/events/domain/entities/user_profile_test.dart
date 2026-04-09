import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/user_profile.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('UserProfile', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create UserProfile with all fields', () {
      final profile = UserProfile(
        id: 'user-001',
        email: 'mario.rossi@school.edu.it',
        name: 'Mario Rossi',
        classValue: '4A',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: now,
      );

      expect(profile.id, 'user-001');
      expect(profile.email, 'mario.rossi@school.edu.it');
      expect(profile.name, 'Mario Rossi');
      expect(profile.classValue, '4A');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('displayName includes class when available', () {
      final withClass = UserProfile(
        id: 'u1',
        email: 'test@test.it',
        name: 'Mario Rossi',
        classValue: '4A',
        createdAt: now,
      );

      final withoutClass = UserProfile(
        id: 'u2',
        email: 'test2@test.it',
        name: 'Lucia Bianchi',
        createdAt: now,
      );

      expect(withClass.displayName, 'Mario Rossi (4A)');
      expect(withoutClass.displayName, 'Lucia Bianchi');
    });

    test('initials extracts first and last name initials', () {
      final profile = UserProfile(
        id: 'u1',
        email: 'test@test.it',
        name: 'Mario Rossi',
        createdAt: now,
      );

      expect(profile.initials, 'MR');
    });

    // =====================================================================
    // Edge Case Tests (E:2)
    // =====================================================================

    test('initials handles single name and empty edge cases', () {
      final singleName = UserProfile(
        id: 'u1',
        email: 'test@test.it',
        name: 'Mario',
        createdAt: now,
      );

      final threeParts = UserProfile(
        id: 'u2',
        email: 'test2@test.it',
        name: 'Mario De Rossi',
        createdAt: now,
      );

      expect(singleName.initials, 'M');
      expect(threeParts.initials, 'MR'); // first + last
    });

    test('equality is based on id only', () {
      final profile1 = UserProfile(
        id: 'user-001',
        email: 'a@test.it',
        name: 'Name A',
        createdAt: now,
      );

      final profile2 = UserProfile(
        id: 'user-001',
        email: 'b@test.it',
        name: 'Name B',
        createdAt: now,
      );

      final profile3 = UserProfile(
        id: 'user-002',
        email: 'a@test.it',
        name: 'Name A',
        createdAt: now,
      );

      expect(profile1, equals(profile2));
      expect(profile1, isNot(equals(profile3)));
      expect(profile1.hashCode, profile2.hashCode);
      expect(profile1.hashCode, isNot(equals(profile3.hashCode)));

      // hasAvatar and isComplete
      expect(profile1.hasAvatar, isFalse);
      expect(profile1.isComplete, isFalse);

      final complete = profile1.copyWith(
        classValue: '5B',
        avatarUrl: 'https://example.com/img.jpg',
      );
      expect(complete.hasAvatar, isTrue);
      expect(complete.isComplete, isTrue);
    });
  });
}
