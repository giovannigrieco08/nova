import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/notifications/domain/usecases/remove_fcm_token.dart';
import 'package:nova/features/notifications/domain/repositories/push_repository_interface.dart';

import '../../../../../mocks/mock_repositories.dart';

void main() {
  late RemoveFcmToken useCase;
  late MockPushRepository mockRepository;

  setUp(() {
    mockRepository = MockPushRepository();
    useCase = RemoveFcmToken(mockRepository);
  });

  group('RemoveFcmToken', () {
    const testFcmToken = 'fcm-token-abc123';

    // ===== HAPPY PATH TESTS =====

    test('removes FCM token and returns true on success', () async {
      when(() => mockRepository.removeToken(any()))
          .thenAnswer((_) async => true);

      final result = await useCase.execute(testFcmToken);

      expect(result, isTrue);
      verify(() => mockRepository.removeToken(testFcmToken)).called(1);
    });

    test('returns false when token removal fails', () async {
      when(() => mockRepository.removeToken(any()))
          .thenAnswer((_) async => false);

      final result = await useCase.execute(testFcmToken);

      expect(result, isFalse);
      verify(() => mockRepository.removeToken(testFcmToken)).called(1);
    });

    // ===== EDGE CASE TEST =====

    test('propagates exception from repository', () async {
      when(() => mockRepository.removeToken(any()))
          .thenThrow(Exception('Network error'));

      expect(
        () => useCase.execute(testFcmToken),
        throwsA(isA<Exception>()),
      );
    });
  });
}
