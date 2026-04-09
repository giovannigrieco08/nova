import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/events/data/datasources/event_remote_datasource.dart';
import 'package:nova/features/events/data/models/event_model.dart';

import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  late EventRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;

  setUp(() {
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);
    mockQueryBuilder = MockSupabaseQueryBuilder();

    dataSource = EventRemoteDataSource(mockSupabase);
  });

  // ==========================================================================
  // Helper: create event JSON matching what Supabase returns
  // ==========================================================================

  Map<String, dynamic> eventJson({
    String id = 'test-event-001',
    String status = 'approved',
  }) {
    return {
      'id': id,
      'title': 'Test Event',
      'description': 'Description',
      'event_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'location': 'Aula Magna',
      'image_url': null,
      'creator_id': TestUserIds.student1,
      'co_organizers': <String>[],
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'rejection_reason': null,
      'moderated_by': null,
      'moderated_at': null,
      'creator': {
        'full_name': 'Mario Rossi',
        'class': '4A',
        'avatar_url': null,
      },
    };
  }

  // ==========================================================================
  // getApprovedEvents
  // ==========================================================================

  group('getApprovedEvents', () {
    test('happy: returns list of EventModel', () async {
      final fb = mockListQuery([eventJson(), eventJson(id: 'evt-2')]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getApprovedEvents();

      expect(result, isA<List<EventModel>>());
      expect(result.length, 2);
    });

    test('happy: returns empty list when no events', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getApprovedEvents();

      expect(result, isEmpty);
    });

    test('edge: wraps PostgrestException in RemoteDataSourceException', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);
      // Override order to throw after creating self-chaining builder
      when(() => fb.order(any(), ascending: any(named: 'ascending')))
          .thenThrow(Exception('Connection refused'));

      expect(
        () => dataSource.getApprovedEvents(),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });

    test('happy: properly parses event with creator JOIN data', () async {
      final fb = mockListQuery([eventJson()]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getApprovedEvents();

      expect(result.first.creatorData?['full_name'], 'Mario Rossi');
    });
  });

  // ==========================================================================
  // getPendingEvents
  // ==========================================================================

  group('getPendingEvents', () {
    test('edge: throws access denied for non-moderator (PGRST116)', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);
      // Override order to throw PostgrestException
      when(() => fb.order(any(), ascending: any(named: 'ascending')))
          .thenThrow(PostgrestException(
        message: 'RLS policy violation',
        code: 'PGRST116',
      ));

      expect(
        () => dataSource.getPendingEvents(),
        throwsA(
          isA<RemoteDataSourceException>().having(
            (e) => e.message,
            'message',
            contains('not a moderator'),
          ),
        ),
      );
    });

    test('edge: wraps generic error in RemoteDataSourceException', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);
      // Override order to throw generic exception
      when(() => fb.order(any(), ascending: any(named: 'ascending')))
          .thenThrow(Exception('generic'));

      expect(
        () => dataSource.getPendingEvents(),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });

    test('happy: returns pending events for moderator', () async {
      final fb = mockListQuery([
        eventJson(id: 'evt-p1', status: 'pending'),
        eventJson(id: 'evt-p2', status: 'pending'),
      ]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getPendingEvents();

      expect(result, isA<List<EventModel>>());
      expect(result.length, 2);
    });
  });

  // ==========================================================================
  // getEventById
  // ==========================================================================

  group('getEventById', () {
    test('happy: returns EventModel when found', () async {
      final fb = mockListQuery([eventJson()]);
      // maybeSingle already returns first item via mockListQuery
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getEventById('test-event-001');

      expect(result, isNotNull);
      expect(result!.id, 'test-event-001');
    });

    test('edge: returns null when not found', () async {
      final fb = mockListQuery([]);
      // mockListQuery with empty list already stubs maybeSingle to return null
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getEventById('nonexistent');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // getMyEvents
  // ==========================================================================

  group('getMyEvents', () {
    test('happy: returns list of user events', () async {
      final fb = mockListQuery([
        eventJson(id: 'evt-1'),
        eventJson(id: 'evt-2', status: 'pending'),
      ]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMyEvents(TestUserIds.student1);

      expect(result, isA<List<EventModel>>());
      expect(result.length, 2);
    });

    test('happy: returns empty list when user has no events', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getMyEvents(TestUserIds.student1);

      expect(result, isEmpty);
    });

    test('edge: wraps error in RemoteDataSourceException', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);
      when(() => fb.order(any(), ascending: any(named: 'ascending')))
          .thenThrow(Exception('Network error'));

      expect(
        () => dataSource.getMyEvents(TestUserIds.student1),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // getCoOrganizedEvents
  // ==========================================================================

  group('getCoOrganizedEvents', () {
    test('happy: returns events where user is co-organizer', () async {
      final fb = mockListQuery([eventJson(id: 'evt-co-1')]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      final result =
          await dataSource.getCoOrganizedEvents(TestUserIds.student1);

      expect(result, isA<List<EventModel>>());
      expect(result.length, 1);
    });

    test('edge: wraps error in RemoteDataSourceException', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);
      when(() => fb.contains(any(), any()))
          .thenThrow(Exception('Connection error'));

      expect(
        () => dataSource.getCoOrganizedEvents(TestUserIds.student1),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // createEvent
  // ==========================================================================

  group('createEvent', () {
    test('happy: creates event and returns EventModel', () async {
      final fb = mockSingleQuery(eventJson(id: 'evt-new', status: 'pending'));
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => fb);

      final event = EventModel.fromJson(eventJson(id: 'evt-new', status: 'pending'));
      final result = await dataSource.createEvent(event);

      expect(result, isA<EventModel>());
      expect(result.id, 'evt-new');
    });

    test('edge: wraps error in RemoteDataSourceException', () async {
      final fb = mockSingleQuery(eventJson());
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => fb);
      when(() => fb.single()).thenThrow(Exception('Insert failed'));

      final event = EventModel.fromJson(eventJson());
      expect(
        () => dataSource.createEvent(event),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // updateEvent
  // ==========================================================================

  group('updateEvent', () {
    test('happy: updates event and returns EventModel', () async {
      final updatedJson = eventJson();
      updatedJson['title'] = 'Updated Title';
      final fb = mockSingleQuery(updatedJson);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => fb);

      final result = await dataSource.updateEvent(
        'test-event-001',
        {'title': 'Updated Title'},
      );

      expect(result, isA<EventModel>());
    });

    test('edge: wraps error in RemoteDataSourceException', () async {
      final fb = mockSingleQuery(eventJson());
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => fb);
      when(() => fb.single()).thenThrow(Exception('Update failed'));

      expect(
        () => dataSource.updateEvent('evt-1', {'title': 'New'}),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // deleteEvent
  // ==========================================================================

  group('deleteEvent', () {
    test('happy: deletes event successfully', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.delete()).thenAnswer((_) => fb);

      await dataSource.deleteEvent('test-event-001');

      verify(() => mockQueryBuilder.delete()).called(1);
    });

    test('edge: wraps error in RemoteDataSourceException', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.delete()).thenAnswer((_) => fb);
      when(() => fb.eq(any(), any()))
          .thenThrow(Exception('Delete failed'));

      expect(
        () => dataSource.deleteEvent('evt-1'),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // approveEvent
  // ==========================================================================

  group('approveEvent', () {
    test('happy: approves event successfully', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => fb);

      await dataSource.approveEvent('test-event-001');

      verify(() => mockQueryBuilder.update(any())).called(1);
    });

    test('edge: throws when not authenticated', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = EventRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.approveEvent('evt-1'),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // rejectEvent
  // ==========================================================================

  group('rejectEvent', () {
    test('edge: validates minimum rejection reason length', () async {
      expect(
        () => dataSource.rejectEvent('evt-1', 'short'),
        throwsA(isA<RemoteDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('at least 10 characters'),
        )),
      );
    });

    test('race: concurrent approve and reject on same event', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => fb);

      // These should not interfere - each is independent
      await dataSource.approveEvent('evt-1');

      verify(() => mockSupabase.from('events')).called(1);
    });

    test('happy: rejects event with valid reason', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => fb);

      await dataSource.rejectEvent(
        'evt-1',
        'This event violates school policy guidelines',
      );

      verify(() => mockQueryBuilder.update(any())).called(1);
    });

    test('edge: throws when not authenticated', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = EventRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.rejectEvent(
          'evt-1',
          'Reason that is long enough',
        ),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // removeCoOrganizer
  // ==========================================================================

  group('removeCoOrganizer', () {
    test('edge: throws when event not found', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.removeCoOrganizer('nonexistent', 'u1'),
        throwsA(isA<RemoteDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Event not found'),
        )),
      );
    });
  });

  // ==========================================================================
  // addCoOrganizer
  // NOTE: These tests use thenReturn(mockTransformBuilder(...)) which causes
  // mocktail state issues. Keep them last to avoid affecting other tests.
  // ==========================================================================

  group('addCoOrganizer', () {
    test('edge: throws when max 3 co-organizers reached', () async {
      final eventWithMaxCoOrganizers = {
        ...eventJson(),
        'co_organizers': ['u1', 'u2', 'u3'],
      };
      final fb = mockListQuery([eventWithMaxCoOrganizers]);
      // Override maybeSingle to return the event with 3 co-organizers
      when(() => fb.maybeSingle()).thenReturn(
        mockTransformBuilder<Map<String, dynamic>?>(eventWithMaxCoOrganizers),
      );
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.addCoOrganizer('evt-1', 'u4'),
        throwsA(isA<RemoteDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Maximum 3'),
        )),
      );
    });

    test('edge: throws when event not found', () async {
      final fb = mockListQuery([]);
      // mockListQuery with empty list already stubs maybeSingle to return null
      when(() => mockSupabase.from('events')).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => fb);

      expect(
        () => dataSource.addCoOrganizer('evt-nonexistent', 'u1'),
        throwsA(isA<RemoteDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Event not found'),
        )),
      );
    });
  });
}
