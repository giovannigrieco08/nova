import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import 'package:nova/features/profile/domain/usecases/create_profile.dart';
import 'package:nova/features/profile/data/repositories/profile_repository.dart';

import '../../../../../fixtures/profile_fixtures.dart';
import '../../../../../fixtures/test_fixtures.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class FakeProfile extends Fake implements Profile {}

void main() {
  late CreateProfile useCase;
  late MockProfileRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeProfile());
  });

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = CreateProfile(mockRepository);
  });

  group('CreateProfile', () {
    // ===== HAPPY PATH TESTS =====

    test('creates profile with all fields and returns created profile',
        () async {
      final expectedProfile = TestProfiles.completeProfile();

      when(() => mockRepository.createProfile(any()))
          .thenAnswer((_) async => expectedProfile);

      final result = await useCase.call(
        userId: TestUserIds.student1,
        email: TestUserEmails.student1,
        fullName: 'Mario Rossi',
        username: 'mario.rossi',
        classYear: '4A',
        avatarUrl: 'https://example.com/avatar.jpg',
        bio: 'Ciao! Sono Mario.',
      );

      expect(result, equals(expectedProfile));
      verify(() => mockRepository.createProfile(any())).called(1);
    });

    test('creates profile with null classYear (incomplete/skip flow)',
        () async {
      final expectedProfile = TestProfiles.incompleteProfile();

      when(() => mockRepository.createProfile(any()))
          .thenAnswer((_) async => expectedProfile);

      final result = await useCase.call(
        userId: TestUserIds.student2,
        email: TestUserEmails.student2,
        fullName: 'Lucia Bianchi',
        username: 'lucia.bianchi',
        classYear: null,
      );

      expect(result, equals(expectedProfile));
      expect(result.classYear, isNull);
      verify(() => mockRepository.createProfile(any())).called(1);
    });

    test('trims fullName and username before creating profile', () async {
      final expectedProfile = TestProfiles.completeProfile();

      when(() => mockRepository.createProfile(any()))
          .thenAnswer((_) async => expectedProfile);

      await useCase.call(
        userId: TestUserIds.student1,
        email: TestUserEmails.student1,
        fullName: '  Mario Rossi  ',
        username: 'mario.rossi',
        classYear: '4A',
      );

      final captured =
          verify(() => mockRepository.createProfile(captureAny())).captured;
      final createdProfile = captured.first as Profile;
      expect(createdProfile.fullName, equals('Mario Rossi'));
    });

    test('creates profile with minimal required fields (no optional fields)',
        () async {
      final expectedProfile = TestProfiles.incompleteProfile();

      when(() => mockRepository.createProfile(any()))
          .thenAnswer((_) async => expectedProfile);

      final result = await useCase.call(
        userId: TestUserIds.student2,
        email: TestUserEmails.student2,
        fullName: 'Lucia Bianchi',
        username: 'lucia.bianchi',
      );

      expect(result, equals(expectedProfile));
      verify(() => mockRepository.createProfile(any())).called(1);
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('throws ValidationException when email is empty', () async {
      expect(
        () => useCase.call(
          userId: TestUserIds.student1,
          email: '',
          fullName: 'Mario Rossi',
          username: 'mario.rossi',
        ),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(() => mockRepository.createProfile(any()));
    });

    test('throws ValidationException when fullName is too short', () async {
      expect(
        () => useCase.call(
          userId: TestUserIds.student1,
          email: TestUserEmails.student1,
          fullName: 'A',
          username: 'mario.rossi',
        ),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(() => mockRepository.createProfile(any()));
    });

    test('throws ValidationException when username contains spaces', () async {
      expect(
        () => useCase.call(
          userId: TestUserIds.student1,
          email: TestUserEmails.student1,
          fullName: 'Mario Rossi',
          username: 'mario rossi',
        ),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(() => mockRepository.createProfile(any()));
    });
  });
}
