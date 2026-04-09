@TestOn('vm')
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nova/features/notifications/data/datasources/fcm_token_remote_datasource.dart';
import 'package:nova/features/notifications/data/models/fcm_token_model.dart';

import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  late FcmTokenRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQb;

  /// A valid-length FCM token for testing (152 chars)
  final validToken = 'a' * 152;

  /// An invalid (too short) FCM token
  final shortToken = 'abc';

  /// An invalid (too long) FCM token
  final longToken = 'a' * 301;

  setUp(() {
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);
    mockQb = MockSupabaseQueryBuilder();

    dataSource = FcmTokenRemoteDataSource(mockSupabase);
  });

  // ==========================================================================
  // Helper: create FCM token JSON matching Supabase response
  // ==========================================================================

  Map<String, dynamic> tokenJson({
    String id = 'token-001',
    String userId = TestUserIds.student1,
    String? token,
    String platform = 'android',
    String? deviceName = 'Android',
  }) {
    return {
      'id': id,
      'user_id': userId,
      'token': token ?? validToken,
      'platform': platform,
      'device_name': deviceName,
      'created_at': DateTime.now().toIso8601String(),
      'last_used_at': DateTime.now().toIso8601String(),
    };
  }

  // ==========================================================================
  // upsertToken
  // ==========================================================================

  group('upsertToken', () {
    test('happy: returns token ID from RPC', () async {
      final fb = mockFilterChain<dynamic>('token-uuid-001');
      when(() => mockSupabase.rpc(
            'upsert_fcm_token',
            params: any(named: 'params'),
          )).thenAnswer((_) => fb);

      final result = await dataSource.upsertToken(validToken);

      expect(result, 'token-uuid-001');
    });

    test('happy: calls RPC with correct params', () async {
      final fb = mockFilterChain<dynamic>('token-uuid-001');
      when(() => mockSupabase.rpc(
            'upsert_fcm_token',
            params: any(named: 'params'),
          )).thenAnswer((_) => fb);

      await dataSource.upsertToken(validToken);

      verify(() => mockSupabase.rpc(
            'upsert_fcm_token',
            params: any(named: 'params'),
          )).called(1);
    });

    test('edge: returns null when user is not authenticated', () async {
      // Create a client with no user
      final noAuthClient = createMockSupabaseClient();
      final ds = FcmTokenRemoteDataSource(noAuthClient);

      final result = await ds.upsertToken(validToken);

      expect(result, isNull);
    });

    test('edge: returns null for token too short (< 100 chars)', () async {
      final result = await dataSource.upsertToken(shortToken);

      expect(result, isNull);
    });

    test('edge: returns null for token too long (> 300 chars)', () async {
      final result = await dataSource.upsertToken(longToken);

      expect(result, isNull);
    });

    test('error: rethrows exception from Supabase RPC', () async {
      when(() => mockSupabase.rpc(
            'upsert_fcm_token',
            params: any(named: 'params'),
          )).thenThrow(Exception('RPC failed'));

      expect(
        () => dataSource.upsertToken(validToken),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // deleteToken
  // ==========================================================================

  group('deleteToken', () {
    test('happy: returns true on successful delete', () async {
      final fb = mockFilterChain<dynamic>(true);
      when(() => mockSupabase.rpc(
            'delete_fcm_token',
            params: any(named: 'params'),
          )).thenAnswer((_) => fb);

      final result = await dataSource.deleteToken(validToken);

      expect(result, true);
    });

    test('happy: returns false when token not found', () async {
      final fb = mockFilterChain<dynamic>(false);
      when(() => mockSupabase.rpc(
            'delete_fcm_token',
            params: any(named: 'params'),
          )).thenAnswer((_) => fb);

      final result = await dataSource.deleteToken(validToken);

      expect(result, false);
    });

    test('edge: returns false when user is not authenticated', () async {
      final noAuthClient = createMockSupabaseClient();
      final ds = FcmTokenRemoteDataSource(noAuthClient);

      final result = await ds.deleteToken(validToken);

      expect(result, false);
    });

    test('happy: calls RPC with correct token param', () async {
      final fb = mockFilterChain<dynamic>(true);
      when(() => mockSupabase.rpc(
            'delete_fcm_token',
            params: any(named: 'params'),
          )).thenAnswer((_) => fb);

      await dataSource.deleteToken(validToken);

      verify(() => mockSupabase.rpc(
            'delete_fcm_token',
            params: any(named: 'params'),
          )).called(1);
    });

    test('error: rethrows exception from Supabase RPC', () async {
      when(() => mockSupabase.rpc(
            'delete_fcm_token',
            params: any(named: 'params'),
          )).thenThrow(Exception('RPC failed'));

      expect(
        () => dataSource.deleteToken(validToken),
        throwsA(isA<Exception>()),
      );
    });

    test('edge: returns false when RPC returns null', () async {
      final fb = mockFilterChain<dynamic>(null);
      when(() => mockSupabase.rpc(
            'delete_fcm_token',
            params: any(named: 'params'),
          )).thenAnswer((_) => fb);

      final result = await dataSource.deleteToken(validToken);

      expect(result, false);
    });
  });

  // ==========================================================================
  // getUserTokens
  // ==========================================================================

  group('getUserTokens', () {
    test('happy: returns list of FcmTokenModel', () async {
      final fb = mockListQuery([
        tokenJson(),
        tokenJson(id: 'token-002'),
      ]);
      when(() => mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getUserTokens();

      expect(result, isA<List<FcmTokenModel>>());
      expect(result.length, 2);
    });

    test('happy: returns empty list when no tokens', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getUserTokens();

      expect(result, isEmpty);
    });

    test('edge: returns empty list when user is not authenticated', () async {
      final noAuthClient = createMockSupabaseClient();
      final ds = FcmTokenRemoteDataSource(noAuthClient);

      final result = await ds.getUserTokens();

      expect(result, isEmpty);
    });

    test('edge: returns empty list on error (swallows exception)', () async {
      when(() => mockSupabase.from('fcm_tokens'))
          .thenThrow(Exception('DB error'));

      final result = await dataSource.getUserTokens();

      expect(result, isEmpty);
    });

    test('happy: correctly parses token fields', () async {
      final json = tokenJson(
        id: 'token-parse',
        platform: 'ios',
        deviceName: 'iPhone',
      );
      final fb = mockListQuery([json]);
      when(() => mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getUserTokens();

      expect(result.first.id, 'token-parse');
      expect(result.first.platform, 'ios');
      expect(result.first.deviceName, 'iPhone');
    });
  });

  // ==========================================================================
  // deleteAllUserTokens
  // ==========================================================================

  group('deleteAllUserTokens', () {
    test('happy: completes without error', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('fcm_tokens'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.deleteAllUserTokens(),
        completes,
      );
    });

    test('edge: returns silently when user is not authenticated', () async {
      final noAuthClient = createMockSupabaseClient();
      final ds = FcmTokenRemoteDataSource(noAuthClient);

      // Should not throw, just return
      await expectLater(
        ds.deleteAllUserTokens(),
        completes,
      );
    });

    test('error: rethrows exception from Supabase', () async {
      when(() => mockSupabase.from('fcm_tokens'))
          .thenThrow(Exception('DB error'));

      expect(
        () => dataSource.deleteAllUserTokens(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // getPushEnabled
  // ==========================================================================

  group('getPushEnabled', () {
    test('happy: returns true when push is enabled', () async {
      final fb = mockSingleQuery({'push_enabled': true});
      when(() => mockSupabase.from('profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getPushEnabled();

      expect(result, true);
    });

    test('happy: returns false when push is disabled', () async {
      final fb = mockSingleQuery({'push_enabled': false});
      when(() => mockSupabase.from('profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getPushEnabled();

      expect(result, false);
    });

    test('edge: returns false when user is not authenticated', () async {
      final noAuthClient = createMockSupabaseClient();
      final ds = FcmTokenRemoteDataSource(noAuthClient);

      final result = await ds.getPushEnabled();

      expect(result, false);
    });

    test('edge: returns true on error (defaults to enabled)', () async {
      when(() => mockSupabase.from('profiles'))
          .thenThrow(Exception('DB error'));

      final result = await dataSource.getPushEnabled();

      expect(result, true);
    });
  });

  // ==========================================================================
  // setPushEnabled
  // ==========================================================================

  group('setPushEnabled', () {
    test('happy: completes without error', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.setPushEnabled(true),
        completes,
      );
    });

    test('happy: calls update with correct value', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('profiles'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.setPushEnabled(false);

      verify(() => mockQb.update({'push_enabled': false})).called(1);
    });

    test('edge: returns silently when user is not authenticated', () async {
      final noAuthClient = createMockSupabaseClient();
      final ds = FcmTokenRemoteDataSource(noAuthClient);

      await expectLater(
        ds.setPushEnabled(true),
        completes,
      );
    });

    test('error: rethrows exception from Supabase', () async {
      when(() => mockSupabase.from('profiles'))
          .thenThrow(Exception('DB error'));

      expect(
        () => dataSource.setPushEnabled(true),
        throwsA(isA<Exception>()),
      );
    });
  });
}
