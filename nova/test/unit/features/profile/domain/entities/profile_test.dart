import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import '../../../../../fixtures/profile_fixtures.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  group('Profile', () {
    // ===================== HAPPY PATH =====================

    test('creates a complete profile with all fields', () {
      final profile = TestProfiles.completeProfile();

      expect(profile.userId, TestUserIds.student1);
      expect(profile.email, TestUserEmails.student1);
      expect(profile.fullName, 'Mario Rossi');
      expect(profile.username, 'mario.rossi');
      expect(profile.classYear, '4A');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.bio, 'Ciao! Sono Mario.');
      expect(profile.role, 'student');
      expect(profile.profileVisible, true);
      expect(profile.deletedAt, isNull);
    });

    test('computed properties return correct values for student', () {
      final profile = TestProfiles.completeProfile();

      expect(profile.isModerator, false);
      expect(profile.isAdmin, false);
      expect(profile.isDeleted, false);
    });

    test('computed properties return correct values for moderator and admin',
        () {
      final moderator = TestProfiles.moderatorProfile();
      expect(moderator.isModerator, true);
      expect(moderator.isAdmin, false);

      final admin = TestProfiles.adminProfile();
      expect(admin.isModerator, true);
      expect(admin.isAdmin, true);
    });

    // ===================== EDGE CASES =====================

    test('isDeleted returns true when deletedAt is set', () {
      final deleted = TestProfiles.deletedProfile();
      expect(deleted.isDeleted, true);
    });

    test('defaults role to student and profileVisible to true', () {
      final profile = Profile(
        userId: 'u1',
        email: 'test@galileimoro.edu.it',
        fullName: 'Test User',
        username: 'test.user',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(profile.role, 'student');
      expect(profile.profileVisible, true);
    });

    test('freezed equality compares all fields', () {
      final a = TestProfiles.completeProfile();
      final b = TestProfiles.completeProfile();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      final c = TestProfiles.completeProfile(fullName: 'Different Name');
      expect(a, isNot(equals(c)));
    });
  });

  group('ProfileExtensions', () {
    // ===================== HAPPY PATH =====================

    test('isComplete returns true when classYear is set', () {
      final profile = TestProfiles.completeProfile();
      expect(profile.isComplete, true);
    });

    test('initials returns correct initials for two-part name', () {
      final profile = TestProfiles.completeProfile(fullName: 'Giovanni Rossi');
      expect(profile.initials, 'GR');
    });

    test('hasAvatar, hasBanner, hasBio return correct values', () {
      final complete = TestProfiles.completeProfile();
      expect(complete.hasAvatar, true);
      expect(complete.hasBio, true);

      // Banner is set on complete profile
      expect(complete.hasBanner, false); // no bannerUrl in fixture

      final incomplete = TestProfiles.incompleteProfile();
      expect(incomplete.hasAvatar, false);
      expect(incomplete.hasBio, false);
    });

    test('classDisplay returns class or fallback', () {
      final complete = TestProfiles.completeProfile();
      expect(complete.classDisplay, '4A');

      final incomplete = TestProfiles.incompleteProfile();
      expect(incomplete.classDisplay, 'Non specificato');
    });

    // ===================== EDGE CASES =====================

    test('isComplete returns false when classYear is null', () {
      final profile = TestProfiles.incompleteProfile();
      expect(profile.isComplete, false);
    });

    test('isComplete returns false when classYear is empty string', () {
      final profile = TestProfiles.completeProfile(classYear: '');
      expect(profile.isComplete, false);
    });

    test('initials handles single-word name', () {
      final profile = TestProfiles.completeProfile(fullName: 'Madonna');
      expect(profile.initials, 'M');
    });

    test('initials handles multi-word name using first and last', () {
      final profile =
          TestProfiles.completeProfile(fullName: 'Marco De Rossi');
      expect(profile.initials, 'MR');
    });

    test('hasBio returns false for whitespace-only bio', () {
      final profile = Profile(
        userId: 'u1',
        email: 'test@galileimoro.edu.it',
        fullName: 'Test User',
        username: 'test.user',
        bio: '   ',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(profile.hasBio, false);
    });

    test('hasAvatar returns false for empty string avatarUrl', () {
      final profile = Profile(
        userId: 'u1',
        email: 'test@galileimoro.edu.it',
        fullName: 'Test User',
        username: 'test.user',
        avatarUrl: '',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(profile.hasAvatar, false);
    });
  });
}
