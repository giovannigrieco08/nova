import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/notifications/domain/usecases/register_fcm_token.dart';
import 'package:nova/features/notifications/domain/repositories/push_repository_interface.dart';

import '../../../../../mocks/mock_repositories.dart';

void main() {
  late RegisterFcmToken useCase;
  late MockPushRepository mockRepository;

  setUp(() {
    mockRepository = MockPushRepository();
    useCase = RegisterFcmToken(mockRepository);
  });

  group('RegisterFcmToken', () {
    const testFcmToken = 'fcm-token-abc123';
    const testTokenId = 'token-id-001';

    // ===== HAPPY PATH TESTS =====

    test('registers FCM token and returns token ID on success', () async {
      when(() => mockRepository.registerToken(any()))
          .thenAnswer((_) async => testTokenId);

      final result = await useCase.execute(testFcmToken);

      expect(result, equals(testTokenId));
      verify(() => mockRepository.registerToken(testFcmToken)).called(1);
    });

    test('returns null when registration fails', () async {
      when(() => mockRepository.registerToken(any()))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(testFcmToken);

      expect(result, isNull);
      verify(() => mockRepository.registerToken(testFcmToken)).called(1);
    });

    // ===== EDGE CASE TEST =====

    test('propagates exception from repository', () async {
      when(() => mockRepository.registerToken(any()))
          .thenThrow(Exception('Network error'));

      expect(
        () => useCase.execute(testFcmToken),
        throwsA(isA<Exception>()),
      );
    });
  });
}
