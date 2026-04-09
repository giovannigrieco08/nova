import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/events/data/repositories/event_repository.dart';
import 'package:nova/features/events/data/datasources/event_remote_datasource.dart';
import 'package:nova/features/events/data/datasources/event_local_datasource.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/domain/entities/event.dart';

import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockEventRemoteDataSource extends Mock implements EventRemoteDataSource {}

class MockEventLocalDataSource extends Mock implements EventLocalDataSource {}

class FakeEventModel extends Fake implements EventModel {}

class FakeFile extends Fake implements File {}

void main() {
  late EventRepositoryImpl repository;
  late MockEventRemoteDataSource mockRemoteDataSource;
  late MockEventLocalDataSource mockLocalDataSource;
  late MockSupabaseClient mockSupabase;

  setUpAll(() {
    registerFallbackValue(FakeEventModel());
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockRemoteDataSource = MockEventRemoteDataSource();
    mockLocalDataSource = MockEventLocalDataSource();
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);

    repository = EventRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      supabase: mockSupabase,
    );
  });

  // ==========================================================================
  // Helper to create a valid EventModel
  // ==========================================================================

  EventModel _createEventModel({
    String id = 'test-event-001',
    String status = 'approved',
    String creatorId = 'test-student-001',
  }) {
    return EventModel(
      id: id,
      title: 'Test Event',
      description: 'A test event description.',
      eventDate: DateTime.now().add(const Duration(days: 7)),
      location: 'Aula Magna',
      imageUrl: 'https://example.com/image.jpg',
      creatorId: creatorId,
      coOrganizers: const [],
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      creatorData: {
        'full_name': 'Mario Rossi',
        'class': '4A',
        'avatar_url': null,
      },
    );
  }

  // ==========================================================================
  // READ OPERATIONS
  // ==========================================================================

  group('getApprovedEvents', () {
    test('happy: returns list of approved events from remote', () async {
      final models = [_createEventModel(), _createEventModel(id: 'evt-2')];
      when(() => mockRemoteDataSource.getApprovedEvents())
          .thenAnswer((_) async => models);

      final result = await repository.getApprovedEvents();

      expect(result, isA<List<Event>>());
      expect(result.length, 2);
      verify(() => mockRemoteDataSource.getApprovedEvents()).called(1);
    });

    test('happy: returns empty list when no approved events', () async {
      when(() => mockRemoteDataSource.getApprovedEvents())
          .thenAnswer((_) async => []);

      final result = await repository.getApprovedEvents();

      expect(result, isEmpty);
    });

    test('edge: propagates RemoteDataSourceException', () async {
      when(() => mockRemoteDataSource.getApprovedEvents())
          .thenThrow(RemoteDataSourceException('Network error'));

      expect(
        () => repository.getApprovedEvents(),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  group('getMyEvents', () {
    test('happy: returns user events from remote', () async {
      final models = [_createEventModel(creatorId: TestUserIds.student1)];
      when(() => mockRemoteDataSource.getMyEvents(TestUserIds.student1))
          .thenAnswer((_) async => models);

      final result = await repository.getMyEvents(TestUserIds.student1);

      expect(result.length, 1);
      verify(() => mockRemoteDataSource.getMyEvents(TestUserIds.student1))
          .called(1);
    });

    test('edge: returns empty list for user with no events', () async {
      when(() => mockRemoteDataSource.getMyEvents(any()))
          .thenAnswer((_) async => []);

      final result = await repository.getMyEvents('nonexistent-user');

      expect(result, isEmpty);
    });
  });

  group('getEventById', () {
    test('happy: returns event when found', () async {
      final model = _createEventModel();
      when(() => mockRemoteDataSource.getEventById('test-event-001'))
          .thenAnswer((_) async => model);

      final result = await repository.getEventById('test-event-001');

      expect(result, isNotNull);
      expect(result!.id, 'test-event-001');
    });

    test('edge: returns null when event not found', () async {
      when(() => mockRemoteDataSource.getEventById(any()))
          .thenAnswer((_) async => null);

      final result = await repository.getEventById('nonexistent');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // WRITE OPERATIONS
  // ==========================================================================

  group('updateEvent', () {
    test('happy: delegates update to remote and returns entity', () async {
      final updatedModel = _createEventModel();
      when(() => mockRemoteDataSource.updateEvent(any(), any()))
          .thenAnswer((_) async => updatedModel);

      final result = await repository.updateEvent(
        'test-event-001',
        {'title': 'Updated Title'},
      );

      expect(result, isA<Event>());
      verify(() => mockRemoteDataSource.updateEvent(
            'test-event-001',
            {'title': 'Updated Title'},
          )).called(1);
    });

    test('edge: wraps remote exception in EventRepositoryException', () async {
      when(() => mockRemoteDataSource.updateEvent(any(), any()))
          .thenThrow(RemoteDataSourceException('DB error'));

      expect(
        () => repository.updateEvent('id', {}),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  group('deleteEvent', () {
    test('happy: deletes event and its image', () async {
      final model = _createEventModel();
      when(() => mockRemoteDataSource.getEventById('test-event-001'))
          .thenAnswer((_) async => model);
      when(() => mockRemoteDataSource.deleteEvent('test-event-001'))
          .thenAnswer((_) async {});

      // Mock storage deletion (deleteEventImage uses supabase storage)
      final mockStorage = MockSupabaseStorageClient();
      final mockStorageFile = MockStorageFileApi();
      when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
      when(() => mockStorage.from(any())).thenAnswer((_) => mockStorageFile);
      when(() => mockStorageFile.remove(any()))
          .thenAnswer((_) async => []);

      await repository.deleteEvent('test-event-001');

      verify(() => mockRemoteDataSource.deleteEvent('test-event-001'))
          .called(1);
    });

    test('edge: wraps error in EventRepositoryException', () async {
      when(() => mockRemoteDataSource.getEventById(any()))
          .thenThrow(Exception('fail'));

      expect(
        () => repository.deleteEvent('test-event-001'),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // MODERATION OPERATIONS
  // ==========================================================================

  group('approveEvent', () {
    test('happy: delegates to remote data source', () async {
      when(() => mockRemoteDataSource.approveEvent('evt-1'))
          .thenAnswer((_) async {});

      await repository.approveEvent('evt-1');

      verify(() => mockRemoteDataSource.approveEvent('evt-1')).called(1);
    });

    test('edge: wraps error in EventRepositoryException', () async {
      when(() => mockRemoteDataSource.approveEvent(any()))
          .thenThrow(RemoteDataSourceException('Not a moderator'));

      expect(
        () => repository.approveEvent('evt-1'),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  group('rejectEvent', () {
    test('happy: delegates to remote with reason', () async {
      when(() => mockRemoteDataSource.rejectEvent(any(), any()))
          .thenAnswer((_) async {});

      await repository.rejectEvent('evt-1', 'Contenuto inappropriato');

      verify(() => mockRemoteDataSource.rejectEvent(
            'evt-1',
            'Contenuto inappropriato',
          )).called(1);
    });

    test('edge: wraps error in EventRepositoryException', () async {
      when(() => mockRemoteDataSource.rejectEvent(any(), any()))
          .thenThrow(RemoteDataSourceException('fail'));

      expect(
        () => repository.rejectEvent('evt-1', 'reason'),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // CO-ORGANIZER OPERATIONS
  // ==========================================================================

  group('addCoOrganizer', () {
    test('happy: delegates to remote data source', () async {
      when(() => mockRemoteDataSource.addCoOrganizer('evt-1', 'user-a'))
          .thenAnswer((_) async {});

      await repository.addCoOrganizer('evt-1', 'user-a');

      verify(() => mockRemoteDataSource.addCoOrganizer('evt-1', 'user-a'))
          .called(1);
    });

    test('race: concurrent addCoOrganizer calls', () async {
      when(() => mockRemoteDataSource.addCoOrganizer(any(), any()))
          .thenAnswer((_) async {});

      // Fire two concurrent calls
      final futures = [
        repository.addCoOrganizer('evt-1', 'user-a'),
        repository.addCoOrganizer('evt-1', 'user-b'),
      ];

      await Future.wait(futures);

      verify(() => mockRemoteDataSource.addCoOrganizer('evt-1', 'user-a'))
          .called(1);
      verify(() => mockRemoteDataSource.addCoOrganizer('evt-1', 'user-b'))
          .called(1);
    });

    test('race: addCoOrganizer fails after concurrent calls exceed max',
        () async {
      when(() => mockRemoteDataSource.addCoOrganizer('evt-1', 'user-c'))
          .thenThrow(RemoteDataSourceException('Maximum 3 co-organizers'));

      expect(
        () => repository.addCoOrganizer('evt-1', 'user-c'),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // ADDITIONAL READ OPERATIONS
  // ==========================================================================

  group('getPendingEvents', () {
    test('happy: returns list of pending events from remote', () async {
      final models = [
        _createEventModel(id: 'evt-p1', status: 'pending'),
        _createEventModel(id: 'evt-p2', status: 'pending'),
      ];
      when(() => mockRemoteDataSource.getPendingEvents())
          .thenAnswer((_) async => models);

      final result = await repository.getPendingEvents();

      expect(result, isA<List<Event>>());
      expect(result.length, 2);
      verify(() => mockRemoteDataSource.getPendingEvents()).called(1);
    });

    test('happy: returns empty list when no pending events', () async {
      when(() => mockRemoteDataSource.getPendingEvents())
          .thenAnswer((_) async => []);

      final result = await repository.getPendingEvents();

      expect(result, isEmpty);
    });

    test('edge: propagates remote exception', () async {
      when(() => mockRemoteDataSource.getPendingEvents())
          .thenThrow(RemoteDataSourceException('Access denied'));

      expect(
        () => repository.getPendingEvents(),
        throwsA(isA<RemoteDataSourceException>()),
      );
    });
  });

  group('getCoOrganizedEvents', () {
    test('happy: returns co-organized events for user', () async {
      final models = [_createEventModel(id: 'evt-co1')];
      when(() => mockRemoteDataSource.getCoOrganizedEvents(TestUserIds.student1))
          .thenAnswer((_) async => models);

      final result =
          await repository.getCoOrganizedEvents(TestUserIds.student1);

      expect(result.length, 1);
      verify(() =>
              mockRemoteDataSource.getCoOrganizedEvents(TestUserIds.student1))
          .called(1);
    });

    test('edge: returns empty list for user with no co-organized events',
        () async {
      when(() => mockRemoteDataSource.getCoOrganizedEvents(any()))
          .thenAnswer((_) async => []);

      final result = await repository.getCoOrganizedEvents('some-user');

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // REMOVE CO-ORGANIZER
  // ==========================================================================

  group('removeCoOrganizer', () {
    test('happy: delegates to remote data source', () async {
      when(() => mockRemoteDataSource.removeCoOrganizer('evt-1', 'user-a'))
          .thenAnswer((_) async {});

      await repository.removeCoOrganizer('evt-1', 'user-a');

      verify(() => mockRemoteDataSource.removeCoOrganizer('evt-1', 'user-a'))
          .called(1);
    });

    test('edge: wraps error in EventRepositoryException', () async {
      when(() => mockRemoteDataSource.removeCoOrganizer(any(), any()))
          .thenThrow(RemoteDataSourceException('Not found'));

      expect(
        () => repository.removeCoOrganizer('evt-1', 'user-x'),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // CREATE EVENT (complex flow)
  // ==========================================================================

  group('createEvent', () {
    test('happy: creates event without image, invites, or help requests',
        () async {
      final inputEvent = TestEvents.pendingEvent();
      final createdModel = _createEventModel(
        id: 'new-evt-001',
        status: 'pending',
        creatorId: TestUserIds.student1,
      );

      when(() => mockRemoteDataSource.createEvent(any()))
          .thenAnswer((_) async => createdModel);
      when(() => mockLocalDataSource.deleteDraft())
          .thenAnswer((_) async {});

      final result = await repository.createEvent(inputEvent);

      expect(result, isA<Event>());
      expect(result.id, 'new-evt-001');
      verify(() => mockRemoteDataSource.createEvent(any())).called(1);
      verify(() => mockLocalDataSource.deleteDraft()).called(1);
    });

    test('happy: creates event with help requests (max 5)', () async {
      final inputEvent = TestEvents.pendingEvent();
      final createdModel = _createEventModel(id: 'new-evt-002', status: 'pending');

      when(() => mockRemoteDataSource.createEvent(any()))
          .thenAnswer((_) async => createdModel);
      when(() => mockLocalDataSource.deleteDraft())
          .thenAnswer((_) async {});

      // Mock Supabase insert for help requests
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('event_help_requests')).thenAnswer((_) => mockQb);
      final fb = mockVoidQuery();
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await repository.createEvent(
        inputEvent,
        helpRequests: ['Need speakers', 'Need chairs'],
      );

      verify(() => mockSupabase.from('event_help_requests')).called(2);
    });

    test('happy: creates event with pending invites', () async {
      final inputEvent = TestEvents.pendingEvent();
      final createdModel = _createEventModel(id: 'new-evt-003', status: 'pending');

      when(() => mockRemoteDataSource.createEvent(any()))
          .thenAnswer((_) async => createdModel);
      when(() => mockLocalDataSource.deleteDraft())
          .thenAnswer((_) async {});

      // Mock Supabase insert for collaboration invites
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('collaboration_invites')).thenAnswer((_) => mockQb);
      final fb = mockVoidQuery();
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await repository.createEvent(
        inputEvent,
        pendingInvites: [TestUserIds.student2],
      );

      verify(() => mockSupabase.from('collaboration_invites')).called(1);
    });

    test('edge: wraps remote error in EventRepositoryException', () async {
      final inputEvent = TestEvents.pendingEvent();

      when(() => mockRemoteDataSource.createEvent(any()))
          .thenThrow(Exception('DB error'));

      expect(
        () => repository.createEvent(inputEvent),
        throwsA(isA<EventRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // DELETE EVENT IMAGE
  // ==========================================================================

  group('deleteEventImage', () {
    test('happy: extracts path and deletes from storage', () async {
      final mockStorage = MockSupabaseStorageClient();
      final mockStorageFile = MockStorageFileApi();
      when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
      when(() => mockStorage.from('event-images'))
          .thenAnswer((_) => mockStorageFile);
      when(() => mockStorageFile.remove(any()))
          .thenAnswer((_) async => []);

      await repository.deleteEventImage(
        'https://proj.supabase.co/storage/v1/object/public/event-images/user1/evt1/123.jpg',
      );

      verify(() => mockStorageFile.remove(['user1/evt1/123.jpg'])).called(1);
    });

    test('edge: does not throw on delete failure', () async {
      final mockStorage = MockSupabaseStorageClient();
      final mockStorageFile = MockStorageFileApi();
      when(() => mockSupabase.storage).thenAnswer((_) => mockStorage);
      when(() => mockStorage.from('event-images'))
          .thenAnswer((_) => mockStorageFile);
      when(() => mockStorageFile.remove(any()))
          .thenThrow(Exception('storage error'));

      // Should not throw - errors are swallowed
      await repository.deleteEventImage(
        'https://proj.supabase.co/storage/v1/object/public/event-images/user1/evt1/123.jpg',
      );
    });

    test('edge: handles invalid URL format without throwing', () async {
      // URL without event-images bucket segment
      await repository.deleteEventImage('https://example.com/invalid/url.jpg');
      // Should not throw
    });
  });

  // ==========================================================================
  // EventRepositoryException
  // ==========================================================================

  group('EventRepositoryException', () {
    test('happy: toString includes message', () {
      final ex = EventRepositoryException('Something went wrong');

      expect(ex.toString(), 'EventRepositoryException: Something went wrong');
      expect(ex.message, 'Something went wrong');
    });
  });
}
