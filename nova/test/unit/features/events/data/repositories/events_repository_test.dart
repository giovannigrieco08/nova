import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nova/features/events/data/repositories/events_repository.dart';
import 'package:nova/features/events/data/data_sources/events_local_data_source.dart';
import 'package:nova/features/events/data/data_sources/events_remote_data_source.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/data/models/comment_model.dart' as evt_comment;
import 'package:nova/features/events/domain/entities/event.dart';

import '../../../../../fixtures/test_fixtures.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockEventsLocalDataSource extends Mock implements EventsLocalDataSource {}

class MockEventsRemoteDataSource extends Mock
    implements EventsRemoteDataSource {}

class FakeEventModel extends Fake implements EventModel {}

void main() {
  late EventsRepository repository;
  late MockEventsLocalDataSource mockLocalDataSource;
  late MockEventsRemoteDataSource mockRemoteDataSource;

  setUpAll(() {
    registerFallbackValue(FakeEventModel());
    registerFallbackValue(<EventModel>[]);
  });

  setUp(() {
    mockLocalDataSource = MockEventsLocalDataSource();
    mockRemoteDataSource = MockEventsRemoteDataSource();

    repository = EventsRepository(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
    );
  });

  // ==========================================================================
  // Helper
  // ==========================================================================

  EventModel _createEventModel({String id = 'test-event-001'}) {
    return EventModel(
      id: id,
      title: 'Test Event',
      description: 'Test description.',
      eventDate: DateTime.now().add(const Duration(days: 7)),
      location: 'Aula Magna',
      imageUrl: null,
      creatorId: TestUserIds.student1,
      coOrganizers: const [],
      status: 'approved',
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
  // getEventsFeed
  // ==========================================================================

  group('getEventsFeed', () {
    test('happy: returns events from remote and caches first page', () async {
      final models = [_createEventModel(), _createEventModel(id: 'evt-2')];
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenAnswer((_) async => models);
      when(() => mockLocalDataSource.saveEventsToCache(any()))
          .thenAnswer((_) async {});

      final result = await repository.getEventsFeed(page: 1, limit: 20);

      expect(result.length, 2);
      expect(result.first, isA<Event>());
      verify(() => mockLocalDataSource.saveEventsToCache(models)).called(1);
    });

    test('happy: returns events from remote without caching page 2', () async {
      final models = [_createEventModel()];
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 2,
            limit: 20,
          )).thenAnswer((_) async => models);

      final result = await repository.getEventsFeed(page: 2, limit: 20);

      expect(result.length, 1);
      verifyNever(() => mockLocalDataSource.saveEventsToCache(any()));
    });

    test('happy: returns empty list from remote', () async {
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenAnswer((_) async => []);
      when(() => mockLocalDataSource.saveEventsToCache(any()))
          .thenAnswer((_) async {});

      final result = await repository.getEventsFeed(page: 1, limit: 20);

      expect(result, isEmpty);
    });

    test('edge: falls back to cache on network error (page 1)', () async {
      final cachedModels = [_createEventModel()];
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenThrow(Exception('Network error'));
      when(() => mockLocalDataSource.getCachedEvents())
          .thenAnswer((_) async => cachedModels);

      final result = await repository.getEventsFeed(page: 1, limit: 20);

      expect(result.length, 1);
      verify(() => mockLocalDataSource.getCachedEvents()).called(1);
    });

    test('edge: rethrows when no cache available on network error', () async {
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenThrow(Exception('Network error'));
      when(() => mockLocalDataSource.getCachedEvents())
          .thenAnswer((_) async => []);

      expect(
        () => repository.getEventsFeed(page: 1, limit: 20),
        throwsA(isA<Exception>()),
      );
    });

    test('edge: rethrows on network error for page > 1 (no cache fallback)',
        () async {
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 2,
            limit: 20,
          )).thenThrow(Exception('Network error'));

      expect(
        () => repository.getEventsFeed(page: 2, limit: 20),
        throwsA(isA<Exception>()),
      );
    });

    test('race: concurrent getEventsFeed calls both succeed', () async {
      final models = [_createEventModel()];
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenAnswer((_) async => models);
      when(() => mockLocalDataSource.saveEventsToCache(any()))
          .thenAnswer((_) async {});

      final futures = [
        repository.getEventsFeed(page: 1, limit: 20),
        repository.getEventsFeed(page: 1, limit: 20),
      ];

      final results = await Future.wait(futures);

      expect(results[0].length, 1);
      expect(results[1].length, 1);
    });

    test('race: concurrent calls where first fails but second succeeds',
        () async {
      int callCount = 0;
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('Network error');
        return [_createEventModel()];
      });
      when(() => mockLocalDataSource.getCachedEvents())
          .thenAnswer((_) async => [_createEventModel()]);
      when(() => mockLocalDataSource.saveEventsToCache(any()))
          .thenAnswer((_) async {});

      // First call fails -> returns cache
      final result1 = await repository.getEventsFeed(page: 1, limit: 20);
      // Second call succeeds
      final result2 = await repository.getEventsFeed(page: 1, limit: 20);

      expect(result1.length, 1);
      expect(result2.length, 1);
    });

    test('race: stale cache invalidation after refresh', () async {
      final staleModels = [_createEventModel(id: 'stale')];
      final freshModels = [_createEventModel(id: 'fresh')];

      // First call fails, returns stale cache
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenThrow(Exception('offline'));
      when(() => mockLocalDataSource.getCachedEvents())
          .thenAnswer((_) async => staleModels);

      final staleResult = await repository.getEventsFeed(page: 1, limit: 20);
      expect(staleResult.first.id, 'stale');

      // Second call succeeds with fresh data
      when(() => mockRemoteDataSource.fetchEventsFeed(
            page: 1,
            limit: 20,
          )).thenAnswer((_) async => freshModels);
      when(() => mockLocalDataSource.saveEventsToCache(any()))
          .thenAnswer((_) async {});

      final freshResult = await repository.getEventsFeed(page: 1, limit: 20);
      expect(freshResult.first.id, 'fresh');
      verify(() => mockLocalDataSource.saveEventsToCache(freshModels))
          .called(1);
    });
  });

  // ==========================================================================
  // getEventById
  // ==========================================================================

  group('getEventById', () {
    test('happy: returns cached event when available (no force refresh)',
        () async {
      final cachedModel = _createEventModel();
      when(() => mockLocalDataSource.getCachedEventById('test-event-001'))
          .thenAnswer((_) async => cachedModel);

      final result = await repository.getEventById('test-event-001');

      expect(result, isA<Event>());
      verifyNever(() => mockRemoteDataSource.fetchEventById(any()));
    });

    test('happy: fetches from remote on cache miss', () async {
      final remoteModel = _createEventModel();
      when(() => mockLocalDataSource.getCachedEventById(any()))
          .thenAnswer((_) async => null);
      when(() => mockRemoteDataSource.fetchEventById('test-event-001'))
          .thenAnswer((_) async => remoteModel);
      when(() => mockLocalDataSource.updateEventInCache(any()))
          .thenAnswer((_) async {});

      final result = await repository.getEventById('test-event-001');

      expect(result, isA<Event>());
      verify(() => mockLocalDataSource.updateEventInCache(remoteModel))
          .called(1);
    });

    test('happy: force refresh bypasses cache', () async {
      final remoteModel = _createEventModel();
      when(() => mockRemoteDataSource.fetchEventById('test-event-001'))
          .thenAnswer((_) async => remoteModel);
      when(() => mockLocalDataSource.updateEventInCache(any()))
          .thenAnswer((_) async {});

      final result = await repository.getEventById(
        'test-event-001',
        forceRefresh: true,
      );

      expect(result, isA<Event>());
      verifyNever(() => mockLocalDataSource.getCachedEventById(any()));
    });

    test('edge: fallback to cache on network error with forceRefresh',
        () async {
      final cachedModel = _createEventModel();
      when(() => mockRemoteDataSource.fetchEventById(any()))
          .thenThrow(Exception('Network error'));
      when(() => mockLocalDataSource.getCachedEventById('test-event-001'))
          .thenAnswer((_) async => cachedModel);

      final result = await repository.getEventById(
        'test-event-001',
        forceRefresh: true,
      );

      expect(result, isA<Event>());
    });

    test('edge: rethrows when network fails and cache empty with forceRefresh',
        () async {
      when(() => mockRemoteDataSource.fetchEventById(any()))
          .thenThrow(Exception('offline'));
      when(() => mockLocalDataSource.getCachedEventById(any()))
          .thenAnswer((_) async => null);

      expect(
        () => repository.getEventById('test-event-001', forceRefresh: true),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // LIKES OPERATIONS
  // ==========================================================================

  group('likeEvent', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.likeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});

      await repository.likeEvent(eventId: 'evt-1', userId: 'user-1');

      verify(() => mockRemoteDataSource.likeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
    });
  });

  group('unlikeEvent', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.unlikeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});

      await repository.unlikeEvent(eventId: 'evt-1', userId: 'user-1');

      verify(() => mockRemoteDataSource.unlikeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
    });
  });

  // ==========================================================================
  // PARTICIPATION OPERATIONS
  // ==========================================================================

  group('participateInEvent', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.participateInEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});

      await repository.participateInEvent(eventId: 'evt-1', userId: 'user-1');

      verify(() => mockRemoteDataSource.participateInEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
    });
  });

  // ==========================================================================
  // REPORT OPERATIONS
  // ==========================================================================

  group('reportEvent', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.reportEvent(
            eventId: any(named: 'eventId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
          )).thenAnswer((_) async {});

      await repository.reportEvent(
        eventId: 'evt-1',
        userId: 'user-1',
        reason: 'inappropriate',
        description: 'Bad content',
      );

      verify(() => mockRemoteDataSource.reportEvent(
            eventId: 'evt-1',
            reporterId: 'user-1',
            reason: 'inappropriate',
            description: 'Bad content',
          )).called(1);
    });
  });

  // ==========================================================================
  // HELP REQUESTS
  // ==========================================================================

  group('getHelpRequests', () {
    test('happy: returns help requests for event', () async {
      when(() => mockRemoteDataSource.fetchHelpRequests('evt-1'))
          .thenAnswer((_) async => [
                {'id': 'hr-1', 'description': 'Need chairs'}
              ]);

      final result = await repository.getHelpRequests('evt-1');

      expect(result.length, 1);
      expect(result.first['description'], 'Need chairs');
    });
  });

  // ==========================================================================
  // INVITATIONS
  // ==========================================================================

  group('inviteUser', () {
    test('happy: delegates to remote and returns result', () async {
      final expected = {
        'id': 'inv-1',
        'event_id': 'evt-1',
        'invitee_id': 'user-2'
      };
      when(() => mockRemoteDataSource.inviteUser(
            eventId: 'evt-1',
            inviterId: 'user-1',
            inviteeId: 'user-2',
          )).thenAnswer((_) async => expected);

      final result = await repository.inviteUser(
        eventId: 'evt-1',
        inviterId: 'user-1',
        inviteeId: 'user-2',
      );

      expect(result['id'], 'inv-1');
    });
  });

  // ==========================================================================
  // updateEvent
  // ==========================================================================

  group('updateEvent', () {
    test('happy: updates event and caches result', () async {
      final updatedModel = _createEventModel(id: 'evt-1');
      when(() => mockRemoteDataSource.updateEvent(
            eventId: 'evt-1',
            updates: {'title': 'Updated Title'},
          )).thenAnswer((_) async => updatedModel);
      when(() => mockLocalDataSource.updateEventInCache(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateEvent(
        eventId: 'evt-1',
        updates: {'title': 'Updated Title'},
      );

      expect(result, isA<Event>());
      verify(() => mockLocalDataSource.updateEventInCache(updatedModel))
          .called(1);
    });

    test('edge: propagates exception from remote', () async {
      when(() => mockRemoteDataSource.updateEvent(
            eventId: any(named: 'eventId'),
            updates: any(named: 'updates'),
          )).thenThrow(Exception('Forbidden'));

      expect(
        () => repository.updateEvent(
          eventId: 'evt-1',
          updates: {'title': 'New'},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ==========================================================================
  // deleteEvent
  // ==========================================================================

  group('deleteEvent', () {
    test('happy: deletes event and removes from cache', () async {
      when(() => mockRemoteDataSource.deleteEvent('evt-1'))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeEventFromCache('evt-1'))
          .thenAnswer((_) async {});

      await repository.deleteEvent('evt-1');

      verify(() => mockRemoteDataSource.deleteEvent('evt-1')).called(1);
      verify(() => mockLocalDataSource.removeEventFromCache('evt-1')).called(1);
    });
  });

  // ==========================================================================
  // clearCache
  // ==========================================================================

  group('clearCache', () {
    test('happy: delegates to local datasource', () async {
      when(() => mockLocalDataSource.clearEventsCache())
          .thenAnswer((_) async {});

      await repository.clearCache();

      verify(() => mockLocalDataSource.clearEventsCache()).called(1);
    });
  });

  // ==========================================================================
  // getLikeCount
  // ==========================================================================

  group('getLikeCount', () {
    test('happy: returns like count from remote', () async {
      when(() => mockRemoteDataSource.getLikeCount('evt-1'))
          .thenAnswer((_) async => 42);

      final result = await repository.getLikeCount('evt-1');

      expect(result, 42);
    });
  });

  // ==========================================================================
  // hasUserLikedEvent
  // ==========================================================================

  group('hasUserLikedEvent', () {
    test('happy: returns true when user liked', () async {
      when(() => mockRemoteDataSource.isEventLiked(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async => true);

      final result = await repository.hasUserLikedEvent(
        eventId: 'evt-1',
        userId: 'user-1',
      );

      expect(result, isTrue);
    });

    test('happy: returns false when user has not liked', () async {
      when(() => mockRemoteDataSource.isEventLiked(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async => false);

      final result = await repository.hasUserLikedEvent(
        eventId: 'evt-1',
        userId: 'user-1',
      );

      expect(result, isFalse);
    });
  });

  // ==========================================================================
  // unparticipateFromEvent
  // ==========================================================================

  group('unparticipateFromEvent', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.unparticipateFromEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});

      await repository.unparticipateFromEvent(
        eventId: 'evt-1',
        userId: 'user-1',
      );

      verify(() => mockRemoteDataSource.unparticipateFromEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
    });
  });

  // ==========================================================================
  // getParticipationCount
  // ==========================================================================

  group('getParticipationCount', () {
    test('happy: returns count from remote', () async {
      when(() => mockRemoteDataSource.getParticipantCount('evt-1'))
          .thenAnswer((_) async => 15);

      final result = await repository.getParticipationCount('evt-1');

      expect(result, 15);
    });
  });

  // ==========================================================================
  // isUserParticipating
  // ==========================================================================

  group('isUserParticipating', () {
    test('happy: returns participation status', () async {
      when(() => mockRemoteDataSource.isParticipating(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async => true);

      final result = await repository.isUserParticipating(
        eventId: 'evt-1',
        userId: 'user-1',
      );

      expect(result, isTrue);
    });
  });

  // ==========================================================================
  // getParticipants
  // ==========================================================================

  group('getParticipants', () {
    test('happy: returns participants list from remote', () async {
      final participants = [
        {'id': 'user-1', 'name': 'Mario'},
        {'id': 'user-2', 'name': 'Lucia'},
      ];
      when(() => mockRemoteDataSource.getParticipants('evt-1'))
          .thenAnswer((_) async => participants);

      final result = await repository.getParticipants('evt-1');

      expect(result.length, 2);
      expect(result.first['name'], 'Mario');
    });
  });

  // ==========================================================================
  // getEventsByCreator
  // ==========================================================================

  group('getEventsByCreator', () {
    test('happy: returns events as domain entities', () async {
      final models = [_createEventModel(id: 'e-1'), _createEventModel(id: 'e-2')];
      when(() => mockRemoteDataSource.fetchEventsByCreator('user-1'))
          .thenAnswer((_) async => models);

      final result = await repository.getEventsByCreator('user-1');

      expect(result.length, 2);
      expect(result.every((e) => e is Event), isTrue);
    });
  });

  // ==========================================================================
  // getUserPendingEvents
  // ==========================================================================

  group('getUserPendingEvents', () {
    test('happy: returns pending events as entities', () async {
      final models = [_createEventModel(id: 'p-1')];
      when(() => mockRemoteDataSource.fetchUserPendingEvents('user-1'))
          .thenAnswer((_) async => models);

      final result = await repository.getUserPendingEvents('user-1');

      expect(result.length, 1);
      expect(result.first, isA<Event>());
    });
  });

  // ==========================================================================
  // getEventsParticipating
  // ==========================================================================

  group('getEventsParticipating', () {
    test('happy: returns participating events as entities', () async {
      final models = [_createEventModel(id: 'ep-1')];
      when(() => mockRemoteDataSource.fetchEventsParticipating('user-1'))
          .thenAnswer((_) async => models);

      final result = await repository.getEventsParticipating('user-1');

      expect(result.length, 1);
      expect(result.first, isA<Event>());
    });
  });

  // ==========================================================================
  // getEventComments
  // ==========================================================================

  group('getEventComments', () {
    test('happy: returns comments from remote', () async {
      final comments = [
        evt_comment.CommentModel(
          id: 'c-1',
          eventId: 'evt-1',
          authorId: 'user-1',
          content: 'Great!',
          createdAt: DateTime.now(),
        ),
        evt_comment.CommentModel(
          id: 'c-2',
          eventId: 'evt-1',
          authorId: 'user-2',
          content: 'Nice!',
          createdAt: DateTime.now(),
        ),
      ];
      when(() => mockRemoteDataSource.fetchComments('evt-1'))
          .thenAnswer((_) async => comments);

      final result = await repository.getEventComments('evt-1');

      expect(result.length, 2);
    });
  });

  // ==========================================================================
  // postComment (events)
  // ==========================================================================

  group('postComment', () {
    test('happy: delegates to remote and returns result', () async {
      final commentModel = evt_comment.CommentModel(
        id: 'c-new',
        eventId: 'evt-1',
        authorId: 'user-1',
        content: 'Hello',
        createdAt: DateTime.now(),
      );
      when(() => mockRemoteDataSource.postComment(
            eventId: 'evt-1',
            authorId: 'user-1',
            text: 'Hello',
          )).thenAnswer((_) async => commentModel);

      final result = await repository.postComment(
        eventId: 'evt-1',
        userId: 'user-1',
        content: 'Hello',
      );

      expect(result, isA<evt_comment.CommentModel>());
    });
  });

  // ==========================================================================
  // hasUserReportedEvent
  // ==========================================================================

  group('hasUserReportedEvent', () {
    test('happy: returns true when already reported', () async {
      when(() => mockRemoteDataSource.hasUserReportedEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async => true);

      final result = await repository.hasUserReportedEvent(
        eventId: 'evt-1',
        userId: 'user-1',
      );

      expect(result, isTrue);
    });

    test('happy: returns false when not reported', () async {
      when(() => mockRemoteDataSource.hasUserReportedEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async => false);

      final result = await repository.hasUserReportedEvent(
        eventId: 'evt-1',
        userId: 'user-1',
      );

      expect(result, isFalse);
    });
  });

  // ==========================================================================
  // searchUsersToInvite
  // ==========================================================================

  group('searchUsersToInvite', () {
    test('happy: returns search results from remote', () async {
      final users = [
        {'id': 'u-1', 'name': 'Mario Rossi'},
      ];
      when(() => mockRemoteDataSource.searchUsersToInvite(
            eventId: 'evt-1',
            currentUserId: 'user-1',
            query: 'Mario',
          )).thenAnswer((_) async => users);

      final result = await repository.searchUsersToInvite(
        eventId: 'evt-1',
        currentUserId: 'user-1',
        query: 'Mario',
      );

      expect(result.length, 1);
      expect(result.first['name'], 'Mario Rossi');
    });
  });

  // ==========================================================================
  // getEventInvitations / getReceivedInvitations
  // ==========================================================================

  group('getEventInvitations', () {
    test('happy: returns invitations for event', () async {
      final invitations = [
        {'id': 'inv-1', 'status': 'pending'},
      ];
      when(() => mockRemoteDataSource.getEventInvitations('evt-1'))
          .thenAnswer((_) async => invitations);

      final result = await repository.getEventInvitations('evt-1');

      expect(result.length, 1);
      expect(result.first['status'], 'pending');
    });
  });

  group('getReceivedInvitations', () {
    test('happy: returns invitations received by user', () async {
      final invitations = [
        {'id': 'inv-1', 'event_id': 'evt-1'},
        {'id': 'inv-2', 'event_id': 'evt-2'},
      ];
      when(() => mockRemoteDataSource.getReceivedInvitations('user-1'))
          .thenAnswer((_) async => invitations);

      final result = await repository.getReceivedInvitations('user-1');

      expect(result.length, 2);
    });
  });

  // ==========================================================================
  // respondToInvitation / cancelInvitation
  // ==========================================================================

  group('respondToInvitation', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.respondToInvitation(
            invitationId: 'inv-1',
            status: 'accepted',
          )).thenAnswer((_) async {});

      await repository.respondToInvitation(
        invitationId: 'inv-1',
        status: 'accepted',
      );

      verify(() => mockRemoteDataSource.respondToInvitation(
            invitationId: 'inv-1',
            status: 'accepted',
          )).called(1);
    });
  });

  group('cancelInvitation', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.cancelInvitation('inv-1'))
          .thenAnswer((_) async {});

      await repository.cancelInvitation('inv-1');

      verify(() => mockRemoteDataSource.cancelInvitation('inv-1')).called(1);
    });
  });

  // ==========================================================================
  // HELP REQUESTS - additional operations
  // ==========================================================================

  group('createHelpRequest', () {
    test('happy: creates and returns help request', () async {
      final expected = {'id': 'hr-1', 'description': 'Need chairs'};
      when(() => mockRemoteDataSource.createHelpRequest(
            eventId: 'evt-1',
            description: 'Need chairs',
          )).thenAnswer((_) async => expected);

      final result = await repository.createHelpRequest(
        eventId: 'evt-1',
        description: 'Need chairs',
      );

      expect(result['id'], 'hr-1');
    });
  });

  group('updateHelpRequest', () {
    test('happy: updates and returns help request', () async {
      final expected = {'id': 'hr-1', 'description': 'Need 20 chairs'};
      when(() => mockRemoteDataSource.updateHelpRequest(
            requestId: 'hr-1',
            updates: {'description': 'Need 20 chairs'},
          )).thenAnswer((_) async => expected);

      final result = await repository.updateHelpRequest(
        requestId: 'hr-1',
        updates: {'description': 'Need 20 chairs'},
      );

      expect(result['description'], 'Need 20 chairs');
    });
  });

  group('fulfillHelpRequest', () {
    test('happy: marks request as fulfilled', () async {
      final expected = {
        'id': 'hr-1',
        'is_fulfilled': true,
        'fulfilled_by': 'user-2',
      };
      when(() => mockRemoteDataSource.updateHelpRequest(
            requestId: 'hr-1',
            updates: {
              'is_fulfilled': true,
              'fulfilled_by': 'user-2',
            },
          )).thenAnswer((_) async => expected);

      final result = await repository.fulfillHelpRequest(
        requestId: 'hr-1',
        fulfilledBy: 'user-2',
      );

      expect(result['is_fulfilled'], true);
      expect(result['fulfilled_by'], 'user-2');
    });
  });

  group('deleteHelpRequest', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.deleteHelpRequest('hr-1'))
          .thenAnswer((_) async {});

      await repository.deleteHelpRequest('hr-1');

      verify(() => mockRemoteDataSource.deleteHelpRequest('hr-1')).called(1);
    });
  });

  // ==========================================================================
  // HELP OFFERS
  // ==========================================================================

  group('getHelpOffers', () {
    test('happy: returns offers for a help request', () async {
      final offers = [
        {'id': 'ho-1', 'user_id': 'user-2', 'message': 'I can help'},
      ];
      when(() => mockRemoteDataSource.fetchHelpOffers('hr-1'))
          .thenAnswer((_) async => offers);

      final result = await repository.getHelpOffers('hr-1');

      expect(result.length, 1);
      expect(result.first['message'], 'I can help');
    });
  });

  group('createHelpOffer', () {
    test('happy: creates offer and returns result', () async {
      final expected = {'id': 'ho-1', 'request_id': 'hr-1'};
      when(() => mockRemoteDataSource.createHelpOffer(
            requestId: 'hr-1',
            userId: 'user-2',
            message: 'I can bring chairs',
          )).thenAnswer((_) async => expected);

      final result = await repository.createHelpOffer(
        requestId: 'hr-1',
        userId: 'user-2',
        message: 'I can bring chairs',
      );

      expect(result['id'], 'ho-1');
    });
  });

  group('acceptHelpOffer', () {
    test('happy: accepts offer via remote', () async {
      final expected = {'id': 'ho-1', 'status': 'accepted'};
      when(() => mockRemoteDataSource.updateHelpOfferStatus(
            offerId: 'ho-1',
            status: 'accepted',
          )).thenAnswer((_) async => expected);

      final result = await repository.acceptHelpOffer('ho-1');

      expect(result['status'], 'accepted');
    });
  });

  group('declineHelpOffer', () {
    test('happy: declines offer via remote', () async {
      final expected = {'id': 'ho-1', 'status': 'declined'};
      when(() => mockRemoteDataSource.updateHelpOfferStatus(
            offerId: 'ho-1',
            status: 'declined',
          )).thenAnswer((_) async => expected);

      final result = await repository.declineHelpOffer('ho-1');

      expect(result['status'], 'declined');
    });
  });

  group('withdrawHelpOffer', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.deleteHelpOffer('ho-1'))
          .thenAnswer((_) async {});

      await repository.withdrawHelpOffer('ho-1');

      verify(() => mockRemoteDataSource.deleteHelpOffer('ho-1')).called(1);
    });
  });

  group('hasUserOfferedHelp', () {
    test('happy: returns true when user has offered', () async {
      when(() => mockRemoteDataSource.hasUserOfferedHelp(
            requestId: 'hr-1',
            userId: 'user-2',
          )).thenAnswer((_) async => true);

      final result = await repository.hasUserOfferedHelp(
        requestId: 'hr-1',
        userId: 'user-2',
      );

      expect(result, isTrue);
    });

    test('happy: returns false when user has not offered', () async {
      when(() => mockRemoteDataSource.hasUserOfferedHelp(
            requestId: 'hr-1',
            userId: 'user-2',
          )).thenAnswer((_) async => false);

      final result = await repository.hasUserOfferedHelp(
        requestId: 'hr-1',
        userId: 'user-2',
      );

      expect(result, isFalse);
    });
  });
}
