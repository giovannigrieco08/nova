import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/profile/domain/usecases/check_profile_complete.dart';
import 'package:nova/features/profile/data/repositories/profile_repository.dart';

import '../../../../../fixtures/test_fixtures.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late CheckProfileComplete useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = CheckProfileComplete(mockRepository);
  });

  group('CheckProfileComplete', () {
    // ===== HAPPY PATH TESTS =====

    test('returns true when profile is complete', () async {
      when(() => mockRepository.isProfileComplete(any()))
          .thenAnswer((_) async => true);

      final result = await useCase.call(TestUserIds.student1);

      expect(result, isTrue);
      verify(() => mockRepository.isProfileComplete(TestUserIds.student1))
          .called(1);
    });

    test('returns false when profile is incomplete (no classYear)', () async {
      when(() => mockRepository.isProfileComplete(any()))
          .thenAnswer((_) async => false);

      final result = await useCase.call(TestUserIds.student2);

      expect(result, isFalse);
      verify(() => mockRepository.isProfileComplete(TestUserIds.student2))
          .called(1);
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('propagates repository exceptions when profile cannot be fetched',
        () async {
      when(() => mockRepository.isProfileComplete(any()))
          .thenThrow(Exception('Network error'));

      expect(
        () => useCase.call(TestUserIds.student1),
        throwsA(isA<Exception>()),
      );
    });

    test('callSync throws UnimplementedError', () {
      expect(
        () => useCase.callSync(TestUserIds.student1),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
