import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/profile/domain/entities/profile.dart';
import 'package:nova/features/profile/domain/usecases/upload_avatar.dart';
import 'package:nova/features/profile/data/services/avatar_upload_service.dart';
import 'package:nova/features/profile/data/repositories/profile_repository.dart';

import '../../../../../fixtures/profile_fixtures.dart';
import '../../../../../fixtures/test_fixtures.dart';

class MockAvatarUploadService extends Mock implements AvatarUploadService {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class FakeFile extends Fake implements File {}

void main() {
  late UploadAvatar useCase;
  late MockAvatarUploadService mockAvatarUploadService;
  late MockProfileRepository mockProfileRepository;

  setUpAll(() {
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockAvatarUploadService = MockAvatarUploadService();
    mockProfileRepository = MockProfileRepository();
    useCase = UploadAvatar(mockAvatarUploadService, mockProfileRepository);
  });

  group('UploadAvatar', () {
    final testUserId = TestUserIds.student1;
    final testFile = File('test_avatar.png');
    const testAvatarUrl = 'https://storage.example.com/avatars/test/avatar.webp';

    // ===== HAPPY PATH TESTS =====

    test('uploads avatar and returns updated profile with new avatar URL',
        () async {
      final updatedProfile = TestProfiles.completeProfile(
        userId: testUserId,
      );

      when(() => mockAvatarUploadService.uploadAvatar(
            userId: any(named: 'userId'),
            imageFile: any(named: 'imageFile'),
          )).thenAnswer((_) async => testAvatarUrl);

      when(() => mockProfileRepository.updateProfile(
            any(),
            any(),
          )).thenAnswer((_) async => updatedProfile);

      final result = await useCase.call(testUserId, testFile);

      expect(result, equals(updatedProfile));
      verify(() => mockAvatarUploadService.uploadAvatar(
            userId: testUserId,
            imageFile: testFile,
          )).called(1);
      verify(() => mockProfileRepository.updateProfile(
            testUserId,
            {'avatar_url': testAvatarUrl},
          )).called(1);
    });

    test('calls upload service before updating profile', () async {
      final callOrder = <String>[];

      when(() => mockAvatarUploadService.uploadAvatar(
            userId: any(named: 'userId'),
            imageFile: any(named: 'imageFile'),
          )).thenAnswer((_) async {
        callOrder.add('upload');
        return testAvatarUrl;
      });

      when(() => mockProfileRepository.updateProfile(
            any(),
            any(),
          )).thenAnswer((_) async {
        callOrder.add('updateProfile');
        return TestProfiles.completeProfile();
      });

      await useCase.call(testUserId, testFile);

      expect(callOrder, equals(['upload', 'updateProfile']));
    });

    test('passes correct avatar_url map to updateProfile', () async {
      when(() => mockAvatarUploadService.uploadAvatar(
            userId: any(named: 'userId'),
            imageFile: any(named: 'imageFile'),
          )).thenAnswer((_) async => testAvatarUrl);

      when(() => mockProfileRepository.updateProfile(
            any(),
            any(),
          )).thenAnswer((_) async => TestProfiles.completeProfile());

      await useCase.call(testUserId, testFile);

      final captured = verify(() => mockProfileRepository.updateProfile(
            testUserId,
            captureAny(),
          )).captured;

      expect(captured.first, equals({'avatar_url': testAvatarUrl}));
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('propagates AvatarUploadException from upload service', () async {
      when(() => mockAvatarUploadService.uploadAvatar(
            userId: any(named: 'userId'),
            imageFile: any(named: 'imageFile'),
          )).thenThrow(AvatarUploadException('Upload failed'));

      expect(
        () => useCase.call(testUserId, testFile),
        throwsA(isA<AvatarUploadException>()),
      );

      verifyNever(() => mockProfileRepository.updateProfile(any(), any()));
    });

    test('propagates exception when profile update fails after upload',
        () async {
      when(() => mockAvatarUploadService.uploadAvatar(
            userId: any(named: 'userId'),
            imageFile: any(named: 'imageFile'),
          )).thenAnswer((_) async => testAvatarUrl);

      when(() => mockProfileRepository.updateProfile(
            any(),
            any(),
          )).thenThrow(Exception('Profile update failed'));

      expect(
        () => useCase.call(testUserId, testFile),
        throwsA(isA<Exception>()),
      );
    });

    test('propagates OfflineModeException from repository', () async {
      when(() => mockAvatarUploadService.uploadAvatar(
            userId: any(named: 'userId'),
            imageFile: any(named: 'imageFile'),
          )).thenAnswer((_) async => testAvatarUrl);

      when(() => mockProfileRepository.updateProfile(
            any(),
            any(),
          )).thenThrow(OfflineModeException('Offline'));

      expect(
        () => useCase.call(testUserId, testFile),
        throwsA(isA<OfflineModeException>()),
      );
    });
  });
}
