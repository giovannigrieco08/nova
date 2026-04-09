import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:nova/features/profile/data/models/profile_model.dart';
import 'package:nova/features/profile/domain/entities/profile_stats.dart';
import '../../../../../mocks/mock_supabase.dart';

// ============================================================================
// HELPERS
// ============================================================================

Map<String, dynamic> _profileJson({
  String userId = 'user-001',
  String fullName = 'Mario Rossi',
}) =>
    {
      'user_id': userId,
      'email': 'mario.rossi@galileimoro.edu.it',
      'full_name': fullName,
      'username': 'mario.rossi',
      'class': '4A',
      'avatar_url': 'https://example.com/avatar.jpg',
      'bio': 'Ciao!',
      'role': 'student',
      'profile_visible': true,
      'created_at': '2025-01-01T00:00:00.000',
      'updated_at': '2025-01-02T00:00:00.000',
    };

/// Creates a MockPostgrestTransformBuilder that throws [error] when awaited.
/// Delegates to a real Future.error so Dart's async machinery (try/catch)
/// handles error propagation correctly.
MockPostgrestTransformBuilder<Map<String, dynamic>> _throwingTransformBuilder(
    Object error) {
  final tb = MockPostgrestTransformBuilder<Map<String, dynamic>>();
  final errorFuture = Future<Map<String, dynamic>>.error(error);
  // Prevent unhandled error by adding a dummy listener
  errorFuture.catchError((_) => <String, dynamic>{});

  when(() => tb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0]
        as dynamic Function(Map<String, dynamic>);
    final onError = invocation.namedArguments[#onError] as Function?;
    return errorFuture.then<dynamic>(onValue, onError: onError);
  });
  return tb;
}

void main() {
  late ProfileRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockSupabaseQueryBuilder mockQueryBuilder;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    when(() => mockSupabase.auth).thenAnswer((_) => mockAuth);
    dataSource = ProfileRemoteDataSource(mockSupabase);
  });

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  // ==========================================================================
  // getProfile - Happy paths
  // ==========================================================================

  group('getProfile', () {
    test('returns profile model from Supabase', () async {
      // Mock profiles query: .select().eq().single() -> Map
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);

      // Mock user_roles query: .select('role').eq() -> List (empty = default student)
      final mockRolesQueryBuilder = MockSupabaseQueryBuilder();
      final rolesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('user_roles'))
          .thenAnswer((_) => mockRolesQueryBuilder);
      when(() => mockRolesQueryBuilder.select('role')).thenAnswer((_) => rolesFb);

      final result = await dataSource.getProfile('user-001');

      expect(result.userId, 'user-001');
      expect(result.fullName, 'Mario Rossi');
      expect(result.role, 'student');
    });

    test('returns admin role when user has admin in user_roles', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);

      final mockRolesQueryBuilder = MockSupabaseQueryBuilder();
      final rolesFb = mockListQuery([
        {'role': 'moderator'},
        {'role': 'admin'},
      ]);
      when(() => mockSupabase.from('user_roles'))
          .thenAnswer((_) => mockRolesQueryBuilder);
      when(() => mockRolesQueryBuilder.select('role')).thenAnswer((_) => rolesFb);

      final result = await dataSource.getProfile('user-001');

      expect(result.role, 'admin');
    });

    // Edge: profile not found (PGRST116)
    test('throws ProfileNotFoundException on PGRST116', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);
      // Override .single() to throw
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: 'PGRST116', message: 'No rows'),
      );
      when(() => profileFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.getProfile('user-001'),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });

    // Edge: non-PGRST116 PostgrestException is rethrown
    test('rethrows non-PGRST116 PostgrestException', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);
      // Override .single() to throw
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: '42501', message: 'RLS violation'),
      );
      when(() => profileFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.getProfile('user-001'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // ==========================================================================
  // createProfile - Happy + Edge
  // ==========================================================================

  group('createProfile', () {
    test('creates profile and returns model from response', () async {
      final model = ProfileModel(
        userId: 'user-001',
        email: 'mario.rossi@galileimoro.edu.it',
        fullName: 'Mario Rossi',
        username: 'mario.rossi',
        classYear: '4A',
        role: 'student',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Mock auth for debug logging
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user-001');
      when(() => mockAuth.currentUser).thenAnswer((_) => mockUser);

      // insert(json) -> .select().single() chain resolves to Map
      final insertFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => insertFb);

      final result = await dataSource.createProfile(model);

      expect(result.userId, 'user-001');
    });

    // Edge: duplicate profile (23505)
    test('throws ProfileAlreadyExistsException on unique constraint', () async {
      final model = ProfileModel(
        userId: 'user-001',
        email: 'mario@galileimoro.edu.it',
        fullName: 'Mario Rossi',
        username: 'mario.rossi',
        role: 'student',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user-001');
      when(() => mockAuth.currentUser).thenAnswer((_) => mockUser);

      final insertFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => insertFb);
      // Override .single() to throw
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: '23505', message: 'Duplicate key'),
      );
      when(() => insertFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.createProfile(model),
        throwsA(isA<ProfileAlreadyExistsException>()),
      );
    });
  });

  // ==========================================================================
  // updateProfile
  // ==========================================================================

  group('updateProfile', () {
    test('updates profile and returns new model', () async {
      // update(data) -> .eq().select().single() chain resolves to Map
      final updateFb =
          mockSingleQuery(_profileJson(fullName: 'Mario Updated'));
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => updateFb);

      final result = await dataSource.updateProfile(
        'user-001',
        {'full_name': 'Mario Updated'},
      );

      expect(result.fullName, 'Mario Updated');
    });

    // Edge: update non-existent profile
    test('throws ProfileNotFoundException on PGRST116 during update', () async {
      final updateFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => updateFb);
      // Override .single() to throw
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: 'PGRST116', message: 'No rows'),
      );
      when(() => updateFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.updateProfile('user-001', {'bio': 'new'}),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });
  });

  // ==========================================================================
  // isUsernameAvailable
  // ==========================================================================

  group('isUsernameAvailable', () {
    test('returns true when username is available', () async {
      final rpcFb = mockFilterChain<dynamic>(true);
      when(() => mockSupabase.rpc('check_username_available',
          params: {'p_username': 'new.user'})).thenAnswer((_) => rpcFb);

      final result = await dataSource.isUsernameAvailable('new.user');

      expect(result, true);
    });

    test('returns false when username is taken', () async {
      final rpcFb = mockFilterChain<dynamic>(false);
      when(() => mockSupabase.rpc('check_username_available',
              params: {'p_username': 'mario.rossi'}))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.isUsernameAvailable('mario.rossi');

      expect(result, false);
    });
  });

  // ==========================================================================
  // getProfileStats
  // ==========================================================================

  group('getProfileStats', () {
    test('returns stats from RPC', () async {
      final rpcFb = mockFilterChain<dynamic>([
        {'events_created_count': 5, 'participations_count': 3}
      ]);
      when(() => mockSupabase.rpc('get_profile_stats',
          params: {'p_user_id': 'user-001'})).thenAnswer((_) => rpcFb);

      final result = await dataSource.getProfileStats('user-001');

      expect(result.eventsCreatedCount, 5);
    });

    test('returns empty stats when RPC returns null', () async {
      final rpcFb = mockFilterChain<dynamic>(null);
      when(() => mockSupabase.rpc('get_profile_stats',
          params: {'p_user_id': 'user-001'})).thenAnswer((_) => rpcFb);

      final result = await dataSource.getProfileStats('user-001');

      expect(result, ProfileStats.empty());
    });

    test('returns empty stats when RPC returns empty list', () async {
      final rpcFb = mockFilterChain<dynamic>(<Map<String, dynamic>>[]);
      when(() => mockSupabase.rpc('get_profile_stats',
          params: {'p_user_id': 'user-001'})).thenAnswer((_) => rpcFb);

      final result = await dataSource.getProfileStats('user-001');

      expect(result, ProfileStats.empty());
    });

    test('returns empty stats on exception', () async {
      when(() => mockSupabase.rpc('get_profile_stats',
              params: {'p_user_id': 'user-001'}))
          .thenThrow(Exception('RPC failed'));

      final result = await dataSource.getProfileStats('user-001');

      expect(result, ProfileStats.empty());
    });
  });

  // ==========================================================================
  // getProfileById
  // ==========================================================================

  group('getProfileById', () {
    test('returns profile model for another user', () async {
      final profileFb = mockSingleQuery(_profileJson(userId: 'user-002'));
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);

      final mockRolesQueryBuilder = MockSupabaseQueryBuilder();
      final rolesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('user_roles'))
          .thenAnswer((_) => mockRolesQueryBuilder);
      when(() => mockRolesQueryBuilder.select('role')).thenAnswer((_) => rolesFb);

      final result = await dataSource.getProfileById('user-002');

      expect(result.userId, 'user-002');
      expect(result.role, 'student');
    });

    test('throws ProfileNotFoundException on PGRST116', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: 'PGRST116', message: 'No rows'),
      );
      when(() => profileFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.getProfileById('user-002'),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });

    test('rethrows non-PGRST116 PostgrestException', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: '42501', message: 'RLS violation'),
      );
      when(() => profileFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.getProfileById('user-002'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // ==========================================================================
  // _getUserRole (tested via getProfile)
  // ==========================================================================

  group('getUserRole (via getProfile)', () {
    test('returns moderator when user has moderator but not admin', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);

      final mockRolesQueryBuilder = MockSupabaseQueryBuilder();
      final rolesFb = mockListQuery([
        {'role': 'student'},
        {'role': 'moderator'},
      ]);
      when(() => mockSupabase.from('user_roles'))
          .thenAnswer((_) => mockRolesQueryBuilder);
      when(() => mockRolesQueryBuilder.select('role')).thenAnswer((_) => rolesFb);

      final result = await dataSource.getProfile('user-001');

      expect(result.role, 'moderator');
    });

    test('defaults to student on roles query error', () async {
      final profileFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => profileFb);

      when(() => mockSupabase.from('user_roles'))
          .thenThrow(Exception('Connection error'));

      final result = await dataSource.getProfile('user-001');

      expect(result.role, 'student');
    });
  });

  // ==========================================================================
  // deleteProfile
  // ==========================================================================

  group('deleteProfile', () {
    test('happy: deletes profile by userId', () async {
      final deleteFb = mockVoidQuery();
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.delete()).thenAnswer((_) => deleteFb);

      await dataSource.deleteProfile('user-001');

      verify(() => mockSupabase.from('profiles')).called(1);
    });
  });

  // ==========================================================================
  // isProfileComplete
  // ==========================================================================

  group('isProfileComplete', () {
    test('returns true when profile is complete', () async {
      final rpcFb = mockFilterChain<dynamic>(true);
      when(() => mockSupabase.rpc('is_profile_complete',
          params: {'p_user_id': 'user-001'})).thenAnswer((_) => rpcFb);

      final result = await dataSource.isProfileComplete('user-001');

      expect(result, true);
    });

    test('returns false when profile is incomplete', () async {
      final rpcFb = mockFilterChain<dynamic>(false);
      when(() => mockSupabase.rpc('is_profile_complete',
          params: {'p_user_id': 'user-001'})).thenAnswer((_) => rpcFb);

      final result = await dataSource.isProfileComplete('user-001');

      expect(result, false);
    });
  });

  // ==========================================================================
  // parseNameFromEmail
  // ==========================================================================

  group('parseNameFromEmail', () {
    test('returns parsed name from valid email', () async {
      final rpcFb = mockFilterChain<dynamic>('Giovanni Rossi');
      when(() => mockSupabase.rpc('parse_name_from_email',
              params: {'email': 'giovanni.rossi@galileimoro.edu.it'}))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource
          .parseNameFromEmail('giovanni.rossi@galileimoro.edu.it');

      expect(result, 'Giovanni Rossi');
    });

    test('returns null for invalid email format', () async {
      final rpcFb = mockFilterChain<dynamic>(null);
      when(() => mockSupabase.rpc('parse_name_from_email',
              params: {'email': 'admin@galileimoro.edu.it'}))
          .thenAnswer((_) => rpcFb);

      final result =
          await dataSource.parseNameFromEmail('admin@galileimoro.edu.it');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // isUsernameAvailableForUpdate
  // ==========================================================================

  group('isUsernameAvailableForUpdate', () {
    test('returns true when username is available excluding current user',
        () async {
      final rpcFb = mockFilterChain<dynamic>(true);
      when(() => mockSupabase.rpc('check_username_available', params: {
            'p_username': 'mario.rossi',
            'p_exclude_user_id': 'user-001',
          })).thenAnswer((_) => rpcFb);

      final result = await dataSource.isUsernameAvailableForUpdate(
          'mario.rossi', 'user-001');

      expect(result, true);
    });

    test('returns false when username is taken by another user', () async {
      final rpcFb = mockFilterChain<dynamic>(false);
      when(() => mockSupabase.rpc('check_username_available', params: {
            'p_username': 'lucia.bianchi',
            'p_exclude_user_id': 'user-001',
          })).thenAnswer((_) => rpcFb);

      final result = await dataSource.isUsernameAvailableForUpdate(
          'lucia.bianchi', 'user-001');

      expect(result, false);
    });
  });

  // ==========================================================================
  // createProfile - additional edge cases
  // ==========================================================================

  group('createProfile - rethrow', () {
    test('rethrows non-23505 PostgrestException', () async {
      final model = ProfileModel(
        userId: 'user-001',
        email: 'mario@galileimoro.edu.it',
        fullName: 'Mario Rossi',
        username: 'mario.rossi',
        role: 'student',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user-001');
      when(() => mockAuth.currentUser).thenAnswer((_) => mockUser);

      final insertFb = mockSingleQuery(_profileJson());
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => insertFb);
      final throwingTb = _throwingTransformBuilder(
        PostgrestException(code: '42501', message: 'Permission denied'),
      );
      when(() => insertFb.single()).thenAnswer((_) => throwingTb);

      await expectLater(
        () => dataSource.createProfile(model),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
