import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/safety/data/repositories/block_repository.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late BlockRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenAnswer((_) => mockAuth);
    when(() => mockAuth.currentUser).thenAnswer((_) => mockUser);
    when(() => mockUser.id).thenReturn('user-001');

    repository = BlockRepository(supabase: mockSupabase);
  });

  group('blockUser', () {
    test('inserts block record and returns UserBlock', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'id': 'block-001',
        'blocker_id': 'user-001',
        'blocked_id': 'user-002',
        'created_at': '2025-06-01T00:00:00.000',
        'moderator_notified': false,
        'notified_at': null,
      });
      when(() => mockSupabase.from('user_blocks')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await repository.blockUser('user-002');

      expect(result.id, 'block-001');
      expect(result.blockerId, 'user-001');
      expect(result.blockedId, 'user-002');
    });

    test('throws when trying to block self', () async {
      expect(
        () => repository.blockUser('user-001'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      expect(
        () => repository.blockUser('user-002'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('unblockUser', () {
    test('deletes block record and returns true', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('user_blocks')).thenAnswer((_) => mockQb);
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      final result = await repository.unblockUser('user-002');

      expect(result, true);
    });
  });

  group('isUserBlocked', () {
    test('returns true when user is blocked', () async {
      when(() => mockSupabase.rpc('is_user_blocked',
              params: {'p_target_user_id': 'user-002'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(true));

      final result = await repository.isUserBlocked('user-002');

      expect(result, true);
    });

    test('returns false when RPC returns null', () async {
      when(() => mockSupabase.rpc('is_user_blocked',
              params: {'p_target_user_id': 'user-002'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(null));

      final result = await repository.isUserBlocked('user-002');

      expect(result, false);
    });
  });

  group('getBlockedUserIds', () {
    test('returns list of blocked user IDs', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {'blocked_id': 'user-002'},
        {'blocked_id': 'user-003'},
      ]);
      when(() => mockSupabase.from('user_blocks')).thenAnswer((_) => mockQb);
      when(() => mockQb.select('blocked_id')).thenAnswer((_) => fb);

      final result = await repository.getBlockedUserIds();

      expect(result, ['user-002', 'user-003']);
    });

    test('returns empty list when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      final result = await repository.getBlockedUserIds();

      expect(result, isEmpty);
    });
  });

  group('unblockUser', () {
    test('throws when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      expect(
        () => repository.unblockUser('user-002'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('non autenticato'),
        )),
      );
    });
  });

  group('getBlockedUsers', () {
    test('throws when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      expect(
        () => repository.getBlockedUsers(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('non autenticato'),
        )),
      );
    });

    test('returns empty list when no blocks exist', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('user_blocks')).thenAnswer((_) => mockQb);
      when(() => mockQb.select('id, blocker_id, blocked_id, created_at, moderator_notified, notified_at'))
          .thenAnswer((_) => fb);

      final result = await repository.getBlockedUsers();

      expect(result, isEmpty);
    });

    test('returns blocks with profile info', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final blocksFb = mockListQuery([
        {
          'id': 'block-001',
          'blocker_id': 'user-001',
          'blocked_id': 'user-002',
          'created_at': '2025-06-01T00:00:00.000',
          'moderator_notified': false,
          'notified_at': null,
        },
      ]);
      when(() => mockSupabase.from('user_blocks')).thenAnswer((_) => mockQb);
      when(() => mockQb.select('id, blocker_id, blocked_id, created_at, moderator_notified, notified_at'))
          .thenAnswer((_) => blocksFb);

      // Second query for profiles
      final mockProfileQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([
        {
          'user_id': 'user-002',
          'full_name': 'Luigi Verdi',
          'username': 'luigi.verdi',
          'avatar_url': null,
        },
      ]);
      // The second call to from('profiles') returns the profile query builder
      // Need to handle the fact that from('user_blocks') is first, then from('profiles')
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockProfileQb);
      when(() => mockProfileQb.select('user_id, full_name, username, avatar_url'))
          .thenAnswer((_) => profilesFb);

      final result = await repository.getBlockedUsers();

      expect(result.length, 1);
      expect(result.first.id, 'block-001');
      expect(result.first.blockedId, 'user-002');
      expect(result.first.blockedUser, isNotNull);
      expect(result.first.blockedUser!.fullName, 'Luigi Verdi');
    });
  });

  group('isBlockedByUser', () {
    test('returns true when blocked by user', () async {
      when(() => mockSupabase.rpc('is_blocked_by_user',
              params: {'p_target_user_id': 'user-002'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(true));

      final result = await repository.isBlockedByUser('user-002');

      expect(result, true);
    });

    test('returns false when not blocked by user', () async {
      when(() => mockSupabase.rpc('is_blocked_by_user',
              params: {'p_target_user_id': 'user-002'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(false));

      final result = await repository.isBlockedByUser('user-002');

      expect(result, false);
    });

    test('returns false when RPC returns null', () async {
      when(() => mockSupabase.rpc('is_blocked_by_user',
              params: {'p_target_user_id': 'user-002'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(null));

      final result = await repository.isBlockedByUser('user-002');

      expect(result, false);
    });
  });

  group('getBlockedByUserIds', () {
    test('returns empty list when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      final result = await repository.getBlockedByUserIds();

      expect(result, isEmpty);
    });

    test('returns empty list (current implementation)', () async {
      final result = await repository.getBlockedByUserIds();

      expect(result, isEmpty);
    });
  });

  group('isUserBlocked', () {
    test('returns false when user is not blocked', () async {
      when(() => mockSupabase.rpc('is_user_blocked',
              params: {'p_target_user_id': 'user-002'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(false));

      final result = await repository.isUserBlocked('user-002');

      expect(result, false);
    });
  });
}
