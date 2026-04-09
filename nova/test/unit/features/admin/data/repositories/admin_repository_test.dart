import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late AdminRepository repository;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    repository = AdminRepository(mockSupabase);
  });

  group('searchUsers', () {
    test('returns matching users from profiles table', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'id': 'user-001',
          'full_name': 'Mario Rossi',
          'email': 'mario@galileimoro.edu.it',
          'class_name': '4A',
        }
      ]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQb);
      when(() => mockQb.select('id, full_name, email, class_name'))
          .thenAnswer((_) => fb);

      final result = await repository.searchUsers('Mario');

      expect(result.length, 1);
      expect(result.first['full_name'], 'Mario Rossi');
    });

    test('returns empty list when no matches', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQb);
      when(() => mockQb.select('id, full_name, email, class_name'))
          .thenAnswer((_) => fb);

      final result = await repository.searchUsers('zzzzz');

      expect(result, isEmpty);
    });

    test('throws Exception on PostgrestException', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => mockQb);
      when(() => mockQb.select('id, full_name, email, class_name'))
          .thenAnswer((_) => fb);
      // Override order to throw
      when(() => fb.order(any(), ascending: any(named: 'ascending'))).thenThrow(
        PostgrestException(message: 'DB error'),
      );

      expect(
        () => repository.searchUsers('test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('promoteToModerator', () {
    test('calls RPC promote_to_moderator', () async {
      when(() => mockSupabase.rpc('promote_to_moderator',
          params: {'p_user_id': 'user-001'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(null));

      await repository.promoteToModerator('user-001');

      verify(() => mockSupabase.rpc('promote_to_moderator',
          params: {'p_user_id': 'user-001'})).called(1);
    });

    test('throws on RPC failure', () async {
      when(() => mockSupabase.rpc('promote_to_moderator',
              params: {'p_user_id': 'user-001'}))
          .thenThrow(PostgrestException(message: 'User not found'));

      expect(
        () => repository.promoteToModerator('user-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('removeModerator', () {
    test('calls RPC remove_moderator_role', () async {
      when(() => mockSupabase.rpc('remove_moderator_role',
          params: {'p_user_id': 'user-001'}))
          .thenAnswer((_) => mockFilterChain<dynamic>(null));

      await repository.removeModerator('user-001');

      verify(() => mockSupabase.rpc('remove_moderator_role',
          params: {'p_user_id': 'user-001'})).called(1);
    });
  });

  group('getSystemStats', () {
    test('returns SystemStats from RPC response', () async {
      when(() => mockSupabase.rpc('get_system_statistics'))
          .thenAnswer((_) => mockFilterChain<dynamic>({
                'total_events': 100,
                'pending_events': 5,
                'approved_events': 80,
                'rejected_events': 15,
                'total_moderators': 3,
                'active_moderators': 2,
                'avg_review_time_hours': 2.5,
                'events_older_than_24h': 1,
              }));

      final result = await repository.getSystemStats();

      expect(result.totalEvents, 100);
      expect(result.pendingEvents, 5);
      expect(result.activeModerators, 2);
      expect(result.avgReviewTimeHours, 2.5);
    });

    test('throws Exception on RPC error', () async {
      when(() => mockSupabase.rpc('get_system_statistics'))
          .thenThrow(PostgrestException(message: 'Permission denied'));

      expect(
        () => repository.getSystemStats(),
        throwsA(isA<Exception>()),
      );
    });

    test('handles partial RPC response with defaults', () async {
      when(() => mockSupabase.rpc('get_system_statistics'))
          .thenAnswer((_) => mockFilterChain<dynamic>(<String, dynamic>{}));

      final result = await repository.getSystemStats();

      expect(result.totalEvents, 0);
      expect(result.pendingEvents, 0);
      expect(result.avgReviewTimeHours, 0.0);
    });
  });

  group('getActivityLog', () {
    test('returns combined moderation and admin log entries', () async {
      final mockModQb = MockSupabaseQueryBuilder();
      final modFb = mockListQuery([
        {
          'id': 'mod-001',
          'event_id': 'event-001',
          'moderator_id': 'mod-user',
          'action': 'approved',
          'rejection_reason': null,
          'created_at': '2025-06-01T12:00:00.000',
          'events': {'title': 'Test Event'},
          'profiles': {'full_name': 'Moderatore'},
        },
      ]);
      when(() => mockSupabase.from('moderation_log')).thenAnswer((_) => mockModQb);
      when(() => mockModQb.select(any())).thenAnswer((_) => modFb);

      final mockAdminQb = MockSupabaseQueryBuilder();
      final adminFb = mockListQuery([
        {
          'id': 'admin-001',
          'admin_id': 'admin-user',
          'target_user_id': 'target-user',
          'action': 'promoted',
          'old_role': 'student',
          'new_role': 'moderator',
          'created_at': '2025-06-01T10:00:00.000',
          'admin_profiles': {'full_name': 'Admin'},
          'target_profiles': {'full_name': 'Promoted User'},
        },
      ]);
      when(() => mockSupabase.from('admin_log')).thenAnswer((_) => mockAdminQb);
      when(() => mockAdminQb.select(any())).thenAnswer((_) => adminFb);

      final result = await repository.getActivityLog();

      expect(result.length, 2);
      expect(result.first.id, 'mod-001');
      expect(result.last.id, 'admin-001');
    });

    test('filters only moderation entries when actionType is approved', () async {
      final mockModQb = MockSupabaseQueryBuilder();
      final modFb = mockListQuery([
        {
          'id': 'mod-002',
          'event_id': 'event-002',
          'moderator_id': 'mod-user',
          'action': 'approved',
          'rejection_reason': null,
          'created_at': '2025-06-02T12:00:00.000',
          'events': {'title': 'Approved Event'},
          'profiles': {'full_name': 'Moderatore'},
        },
      ]);
      when(() => mockSupabase.from('moderation_log')).thenAnswer((_) => mockModQb);
      when(() => mockModQb.select(any())).thenAnswer((_) => modFb);

      // admin_log should NOT be queried for 'approved' filter
      final result = await repository.getActivityLog(actionType: 'approved');

      expect(result.length, 1);
      expect(result.first.type, 'moderation');
      expect(result.first.action, 'approved');
      verifyNever(() => mockSupabase.from('admin_log'));
    });

    test('filters only admin entries when actionType is promoted', () async {
      final mockAdminQb = MockSupabaseQueryBuilder();
      final adminFb = mockListQuery([
        {
          'id': 'admin-002',
          'admin_id': 'admin-user',
          'target_user_id': 'target-user',
          'action': 'promoted',
          'old_role': 'student',
          'new_role': 'moderator',
          'created_at': '2025-06-02T10:00:00.000',
          'admin_profiles': {'full_name': 'Admin'},
          'target_profiles': {'full_name': 'User'},
        },
      ]);
      when(() => mockSupabase.from('admin_log')).thenAnswer((_) => mockAdminQb);
      when(() => mockAdminQb.select(any())).thenAnswer((_) => adminFb);

      final result = await repository.getActivityLog(actionType: 'promoted');

      expect(result.length, 1);
      expect(result.first.type, 'admin');
      expect(result.first.action, 'promoted');
      verifyNever(() => mockSupabase.from('moderation_log'));
    });

    test('applies date range filters', () async {
      final mockModQb = MockSupabaseQueryBuilder();
      final modFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('moderation_log')).thenAnswer((_) => mockModQb);
      when(() => mockModQb.select(any())).thenAnswer((_) => modFb);

      final mockAdminQb = MockSupabaseQueryBuilder();
      final adminFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('admin_log')).thenAnswer((_) => mockAdminQb);
      when(() => mockAdminQb.select(any())).thenAnswer((_) => adminFb);

      final startDate = DateTime(2025, 6, 1);
      final endDate = DateTime(2025, 6, 30);

      final result = await repository.getActivityLog(
        startDate: startDate,
        endDate: endDate,
      );

      expect(result, isEmpty);
      // Verify gte and lte were called on both filter builders
      verify(() => modFb.gte('created_at', startDate.toIso8601String())).called(1);
      verify(() => modFb.lte('created_at', endDate.toIso8601String())).called(1);
      verify(() => adminFb.gte('created_at', startDate.toIso8601String())).called(1);
      verify(() => adminFb.lte('created_at', endDate.toIso8601String())).called(1);
    });

    test('sorts combined entries by timestamp descending', () async {
      final mockModQb = MockSupabaseQueryBuilder();
      final modFb = mockListQuery([
        {
          'id': 'mod-old',
          'event_id': 'event-001',
          'moderator_id': 'mod-user',
          'action': 'approved',
          'rejection_reason': null,
          'created_at': '2025-06-01T08:00:00.000',
          'events': {'title': 'Old Event'},
          'profiles': {'full_name': 'Mod'},
        },
      ]);
      when(() => mockSupabase.from('moderation_log')).thenAnswer((_) => mockModQb);
      when(() => mockModQb.select(any())).thenAnswer((_) => modFb);

      final mockAdminQb = MockSupabaseQueryBuilder();
      final adminFb = mockListQuery([
        {
          'id': 'admin-new',
          'admin_id': 'admin-user',
          'target_user_id': 'target-user',
          'action': 'promoted',
          'old_role': 'student',
          'new_role': 'moderator',
          'created_at': '2025-06-02T12:00:00.000',
          'admin_profiles': {'full_name': 'Admin'},
          'target_profiles': {'full_name': 'User'},
        },
      ]);
      when(() => mockSupabase.from('admin_log')).thenAnswer((_) => mockAdminQb);
      when(() => mockAdminQb.select(any())).thenAnswer((_) => adminFb);

      final result = await repository.getActivityLog();

      expect(result.length, 2);
      // Newest first
      expect(result.first.id, 'admin-new');
      expect(result.last.id, 'mod-old');
    });

    test('handles null profiles gracefully with fallback names', () async {
      final mockModQb = MockSupabaseQueryBuilder();
      final modFb = mockListQuery([
        {
          'id': 'mod-003',
          'event_id': 'event-003',
          'moderator_id': 'mod-user',
          'action': 'rejected',
          'rejection_reason': 'Inappropriate',
          'created_at': '2025-06-01T12:00:00.000',
          'events': null,
          'profiles': null,
        },
      ]);
      when(() => mockSupabase.from('moderation_log')).thenAnswer((_) => mockModQb);
      when(() => mockModQb.select(any())).thenAnswer((_) => modFb);

      final mockAdminQb = MockSupabaseQueryBuilder();
      final adminFb = mockListQuery([
        {
          'id': 'admin-003',
          'admin_id': 'admin-user',
          'target_user_id': 'target-user',
          'action': 'removed',
          'old_role': 'moderator',
          'new_role': 'student',
          'created_at': '2025-06-01T10:00:00.000',
          'admin_profiles': null,
          'target_profiles': null,
        },
      ]);
      when(() => mockSupabase.from('admin_log')).thenAnswer((_) => mockAdminQb);
      when(() => mockAdminQb.select(any())).thenAnswer((_) => adminFb);

      final result = await repository.getActivityLog();

      expect(result.length, 2);
      final modEntry = result.firstWhere((e) => e.type == 'moderation');
      expect(modEntry.actorName, 'Moderatore sconosciuto');
      expect(modEntry.eventTitle, isNull);
      expect(modEntry.rejectionReason, 'Inappropriate');

      final adminEntry = result.firstWhere((e) => e.type == 'admin');
      expect(adminEntry.actorName, 'Admin sconosciuto');
      expect(adminEntry.targetUserName, isNull);
    });

    test('throws Exception on PostgrestException', () async {
      final mockModQb = MockSupabaseQueryBuilder();
      final modFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('moderation_log')).thenAnswer((_) => mockModQb);
      when(() => mockModQb.select(any())).thenAnswer((_) => modFb);
      // Override order to throw a PostgrestException
      when(() => modFb.order(any(), ascending: any(named: 'ascending'))).thenThrow(
        PostgrestException(message: 'Permission denied'),
      );

      expect(
        () => repository.getActivityLog(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to fetch activity log'),
        )),
      );
    });
  });

  group('getModerators', () {
    test('returns list of Moderator entities from query', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'user_id': 'mod-001',
          'profiles': {
            'full_name': 'Mario Rossi',
            'email': 'mario@galileimoro.edu.it',
            'class_name': '4A',
          },
          'moderator_stats': {
            'total_reviews': 50,
            'reviews_this_week': 10,
            'approval_rate_percent': 85.0,
            'last_review_at': '2025-06-01T12:00:00.000',
          },
        },
      ]);
      when(() => mockSupabase.from('user_roles')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await repository.getModerators();

      expect(result.length, 1);
      expect(result.first.userId, 'mod-001');
      expect(result.first.fullName, 'Mario Rossi');
      expect(result.first.totalReviews, 50);
      expect(result.first.reviewsThisWeek, 10);
      expect(result.first.approvalRatePercent, 85.0);
      expect(result.first.lastReviewAt, isNotNull);
    });

    test('handles moderator with null stats', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([
        {
          'user_id': 'mod-002',
          'profiles': {
            'full_name': 'Luigi Verdi',
            'email': 'luigi@galileimoro.edu.it',
            'class_name': '3B',
          },
          'moderator_stats': null,
        },
      ]);
      when(() => mockSupabase.from('user_roles')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await repository.getModerators();

      expect(result.length, 1);
      expect(result.first.userId, 'mod-002');
      expect(result.first.totalReviews, 0);
      expect(result.first.reviewsThisWeek, 0);
      expect(result.first.approvalRatePercent, 0.0);
      expect(result.first.lastReviewAt, isNull);
    });

    test('throws Exception on PostgrestException', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('user_roles')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);
      when(() => fb.eq(any(), any())).thenThrow(
        PostgrestException(message: 'RLS violation'),
      );

      expect(
        () => repository.getModerators(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to fetch moderators'),
        )),
      );
    });
  });

  group('removeModerator - error handling', () {
    test('throws Exception on generic error', () async {
      when(() => mockSupabase.rpc('remove_moderator_role',
              params: {'p_user_id': 'user-001'}))
          .thenThrow(Exception('Unknown error'));

      expect(
        () => repository.removeModerator('user-001'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to remove moderator'),
        )),
      );
    });

    test('throws Exception on PostgrestException', () async {
      when(() => mockSupabase.rpc('remove_moderator_role',
              params: {'p_user_id': 'user-001'}))
          .thenThrow(PostgrestException(message: 'Not a moderator'));

      expect(
        () => repository.removeModerator('user-001'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to remove moderator'),
        )),
      );
    });
  });

  group('promoteToModerator - generic error', () {
    test('throws Exception wrapping generic error', () async {
      when(() => mockSupabase.rpc('promote_to_moderator',
              params: {'p_user_id': 'user-001'}))
          .thenThrow(Exception('Timeout'));

      expect(
        () => repository.promoteToModerator('user-001'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to promote user'),
        )),
      );
    });
  });
}
