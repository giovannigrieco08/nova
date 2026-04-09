import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import '../../../../../fixtures/profile_fixtures.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 30);
  final updated = DateTime(2025, 6, 16, 12, 0);

  ProfileModel createModel({
    String userId = 'user-001',
    String email = 'mario@galileimoro.edu.it',
    String fullName = 'Mario Rossi',
    String username = 'mario.rossi',
    String? classYear = '4A',
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String role = 'student',
    bool profileVisible = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ProfileModel(
      userId: userId,
      email: email,
      fullName: fullName,
      username: username,
      classYear: classYear,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      bio: bio,
      role: role,
      profileVisible: profileVisible,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? updated,
      deletedAt: deletedAt,
    );
  }

  group('ProfileModel', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields correctly', () {
      final model = createModel(
        avatarUrl: 'https://example.com/avatar.jpg',
        bio: 'Hello!',
      );

      expect(model.userId, 'user-001');
      expect(model.email, 'mario@galileimoro.edu.it');
      expect(model.fullName, 'Mario Rossi');
      expect(model.username, 'mario.rossi');
      expect(model.classYear, '4A');
      expect(model.avatarUrl, 'https://example.com/avatar.jpg');
      expect(model.bio, 'Hello!');
      expect(model.role, 'student');
      expect(model.profileVisible, true);
    });

    test('toEntity converts to Profile domain entity correctly', () {
      final model = createModel(
        avatarUrl: 'https://example.com/avatar.jpg',
        bio: 'Bio text',
      );

      final entity = model.toEntity();

      expect(entity, isA<Profile>());
      expect(entity.userId, model.userId);
      expect(entity.email, model.email);
      expect(entity.fullName, model.fullName);
      expect(entity.username, model.username);
      expect(entity.classYear, model.classYear);
      expect(entity.avatarUrl, model.avatarUrl);
      expect(entity.bio, model.bio);
      expect(entity.role, model.role);
      expect(entity.profileVisible, model.profileVisible);
      expect(entity.createdAt, model.createdAt);
      expect(entity.updatedAt, model.updatedAt);
    });

    test('fromEntity creates model from Profile entity', () {
      final profile = TestProfiles.completeProfile();
      final model = ProfileModel.fromEntity(profile);

      expect(model.userId, profile.userId);
      expect(model.email, profile.email);
      expect(model.fullName, profile.fullName);
      expect(model.username, profile.username);
      expect(model.classYear, profile.classYear);
      expect(model.role, profile.role);
    });

    test('copyWith replaces specified fields only', () {
      final model = createModel();
      final modified = model.copyWith(fullName: 'Luigi Verdi', bio: 'New bio');

      expect(modified.fullName, 'Luigi Verdi');
      expect(modified.bio, 'New bio');
      expect(modified.userId, model.userId);
      expect(modified.email, model.email);
    });

    test('equality is based on userId', () {
      final a = createModel(userId: 'user-001', fullName: 'Name A');
      final b = createModel(userId: 'user-001', fullName: 'Name B');
      final c = createModel(userId: 'user-002');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    // ===================== EDGE CASES =====================

    test('fromJson handles valid complete JSON', () {
      final json = {
        'user_id': 'u1',
        'email': 'test@galileimoro.edu.it',
        'full_name': 'Test User',
        'username': 'test.user',
        'class': '5B',
        'avatar_url': 'https://example.com/a.jpg',
        'banner_url': 'https://example.com/b.jpg',
        'bio': 'Some bio',
        'role': 'moderator',
        'profile_visible': false,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-02T00:00:00.000Z',
        'deleted_at': null,
      };

      final model = ProfileModel.fromJson(json);

      expect(model.userId, 'u1');
      expect(model.fullName, 'Test User');
      expect(model.classYear, '5B');
      expect(model.role, 'moderator');
      expect(model.profileVisible, false);
      expect(model.deletedAt, isNull);
    });

    test('fromJson uses default values for missing fields', () {
      final json = <String, dynamic>{
        'created_at': null,
        'updated_at': null,
      };

      final model = ProfileModel.fromJson(json);

      expect(model.userId, '');
      expect(model.email, '');
      expect(model.fullName, 'Utente');
      expect(model.username, 'utente');
      expect(model.role, 'student');
    });

    test('toJson excludes includeToJson: false fields', () {
      final model = createModel();
      final json = model.toJson();

      // These fields have includeToJson: false
      expect(json.containsKey('email'), false);
      expect(json.containsKey('role'), false);
      expect(json.containsKey('created_at'), false);
      expect(json.containsKey('updated_at'), false);
      expect(json.containsKey('deleted_at'), false);

      // These should be included
      expect(json.containsKey('user_id'), true);
      expect(json.containsKey('full_name'), true);
      expect(json.containsKey('username'), true);
    });

    test('fromEntity and toEntity roundtrip preserves data', () {
      final original = TestProfiles.completeProfile();
      final model = ProfileModel.fromEntity(original);
      final roundtripped = model.toEntity();

      expect(roundtripped.userId, original.userId);
      expect(roundtripped.email, original.email);
      expect(roundtripped.fullName, original.fullName);
      expect(roundtripped.username, original.username);
      expect(roundtripped.classYear, original.classYear);
      expect(roundtripped.avatarUrl, original.avatarUrl);
      expect(roundtripped.bannerUrl, original.bannerUrl);
      expect(roundtripped.bio, original.bio);
      expect(roundtripped.role, original.role);
      expect(roundtripped.profileVisible, original.profileVisible);
      expect(roundtripped.createdAt, original.createdAt);
      expect(roundtripped.updatedAt, original.updatedAt);
      expect(roundtripped.deletedAt, original.deletedAt);
    });
  });
}
