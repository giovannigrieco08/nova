import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/notifications/data/datasources/fcm_token_remote_datasource.dart';
import 'package:nova/features/notifications/data/models/fcm_token_model.dart';
import 'package:nova/features/notifications/data/repositories/push_repository.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockFcmTokenRemoteDataSource extends Mock
    implements FcmTokenRemoteDataSource {}

// ============================================================================
// HELPERS
// ============================================================================

FcmTokenModel _testTokenModel({String id = 'token-001'}) {
  return FcmTokenModel(
    id: id,
    userId: 'user-001',
    token: 'fcm-token-value-' + 'x' * 140,
    platform: 'android',
    deviceName: 'Android',
    createdAt: DateTime(2025, 1, 1),
    lastUsedAt: DateTime(2025, 1, 2),
  );
}

void main() {
  late PushRepositoryImpl repository;
  late MockFcmTokenRemoteDataSource mockRemote;

  setUp(() {
    mockRemote = MockFcmTokenRemoteDataSource();
    repository = PushRepositoryImpl(mockRemote);
  });

  // ==========================================================================
  // registerToken - Happy
  // ==========================================================================

  group('registerToken', () {
    test('delegates to remote upsertToken and returns token id', () async {
      when(() => mockRemote.upsertToken('fcm-token-abc'))
          .thenAnswer((_) async => 'token-id-123');

      final result = await repository.registerToken('fcm-token-abc');

      expect(result, 'token-id-123');
      verify(() => mockRemote.upsertToken('fcm-token-abc')).called(1);
    });

    // Edge: remote returns null (unauthenticated / invalid token)
    test('returns null when remote returns null', () async {
      when(() => mockRemote.upsertToken(any()))
          .thenAnswer((_) async => null);

      final result = await repository.registerToken('short-token');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // removeToken - Happy + Edge
  // ==========================================================================

  group('removeToken', () {
    test('delegates to remote deleteToken', () async {
      when(() => mockRemote.deleteToken('fcm-token-abc'))
          .thenAnswer((_) async => true);

      final result = await repository.removeToken('fcm-token-abc');

      expect(result, true);
    });

    test('returns false when remote fails gracefully', () async {
      when(() => mockRemote.deleteToken(any()))
          .thenAnswer((_) async => false);

      final result = await repository.removeToken('nonexistent-token');

      expect(result, false);
    });
  });

  // ==========================================================================
  // getUserTokens
  // ==========================================================================

  group('getUserTokens', () {
    test('returns list of FcmToken entities', () async {
      when(() => mockRemote.getUserTokens())
          .thenAnswer((_) async => [_testTokenModel(), _testTokenModel(id: 'token-002')]);

      final result = await repository.getUserTokens();

      expect(result.length, 2);
      expect(result.first.id, 'token-001');
      expect(result.last.id, 'token-002');
    });
  });

  // ==========================================================================
  // isPushEnabled + setPushEnabled
  // ==========================================================================

  group('push settings', () {
    test('isPushEnabled delegates to remote', () async {
      when(() => mockRemote.getPushEnabled())
          .thenAnswer((_) async => true);

      expect(await repository.isPushEnabled(), true);
    });

    test('setPushEnabled delegates to remote', () async {
      when(() => mockRemote.setPushEnabled(false))
          .thenAnswer((_) async {});

      await repository.setPushEnabled(false);

      verify(() => mockRemote.setPushEnabled(false)).called(1);
    });
  });
}
