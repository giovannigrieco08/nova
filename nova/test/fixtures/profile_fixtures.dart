/// Profile test fixtures
///
/// Reusable test data for profile-related tests.

import 'package:nova/features/profile/domain/entities/profile.dart';
import 'test_fixtures.dart';

/// Test profile fixtures
class TestProfiles {
  static Profile completeProfile({
    String? userId,
    String? fullName,
    String? classYear,
  }) {
    return Profile(
      userId: userId ?? TestUserIds.student1,
      email: TestUserEmails.student1,
      fullName: fullName ?? 'Mario Rossi',
      username: 'mario.rossi',
      classYear: classYear ?? '4A',
      avatarUrl: 'https://example.com/avatar.jpg',
      bio: 'Ciao! Sono Mario.',
      role: 'student',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
    );
  }

  static Profile incompleteProfile({
    String? userId,
  }) {
    return Profile(
      userId: userId ?? TestUserIds.student2,
      email: TestUserEmails.student2,
      fullName: 'Lucia Bianchi',
      username: 'lucia.bianchi',
      classYear: null, // incomplete
      role: 'student',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );
  }

  static Profile moderatorProfile() {
    return Profile(
      userId: TestUserIds.moderator,
      email: TestUserEmails.moderator,
      fullName: 'Prof Moderatore',
      username: 'prof.moderatore',
      classYear: 'Docente',
      role: 'moderator',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );
  }

  static Profile adminProfile() {
    return Profile(
      userId: TestUserIds.admin,
      email: TestUserEmails.admin,
      fullName: 'Admin Nova',
      username: 'admin.nova',
      classYear: 'Staff',
      role: 'admin',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );
  }

  static Profile deletedProfile() {
    return Profile(
      userId: 'deleted-user-001',
      email: 'deleted@galileimoro.edu.it',
      fullName: 'Utente Eliminato',
      username: 'utente.eliminato',
      classYear: '3C',
      role: 'student',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 6, 1),
      deletedAt: DateTime(2025, 6, 1),
    );
  }

  TestProfiles._();
}
