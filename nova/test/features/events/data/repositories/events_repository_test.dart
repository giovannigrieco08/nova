// =====================================================================
// Nova - Events Repository Unit Tests
// =====================================================================
// Purpose: Test EventsRepository with comprehensive event lifecycle scenarios
// Architecture: mocktail for mocking data sources, tests cache-first pattern
// =====================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/events/data/repositories/events_repository.dart';
import 'package:nova/features/events/data/data_sources/events_local_data_source.dart';
import 'package:nova/features/events/data/data_sources/events_remote_data_source.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';

// =====================================================================
// Mock Classes
// =====================================================================

/// Mock EventsLocalDataSource for testing
class MockEventsLocalDataSource extends Mock implements EventsLocalDataSource {}

/// Mock EventsRemoteDataSource for testing
class MockEventsRemoteDataSource extends Mock implements EventsRemoteDataSource {}

// =====================================================================
// Test Helper Functions
// =====================================================================

/// Create test EventModel with default values
EventModel createTestEventModel({
  String id = 'test-event-id',
  String title = 'Test Event',
  String description = 'This is a test event description',
  DateTime? eventDate,
  String? location,
  String? imageUrl,
  String creatorId = 'test-creator-id',
  List<String> coOrganizers = const [],
  String status = 'approved',
  String? rejectionReason,
  String? moderatedBy,
  DateTime? moderatedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    title: title,
    description: description,
    eventDate: eventDate ?? now.add(const Duration(days: 7)),
    location: location,
    imageUrl: imageUrl,
    creatorId: creatorId,
    coOrganizers: coOrganizers,
    status: status,
    rejectionReason: rejectionReason,
    moderatedBy: moderatedBy,
    moderatedAt: moderatedAt,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

/// Create list of test events
List<EventModel> createTestEventsList({int count = 3}) {
  return List.generate(
    count,
    (index) => createTestEventModel(
      id: 'event-$index',
      title: 'Test Event $index',
    ),
  );
}

// =====================================================================
// Test Suite
// =====================================================================

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(<EventModel>[]);
    registerFallbackValue(createTestEventModel());
  });

  group('EventsRepository', () {
    late MockEventsLocalDataSource mockLocalDataSource;
    late MockEventsRemoteDataSource mockRemoteDataSource;
    late EventsRepository repository;

    setUp(() {
      mockLocalDataSource = MockEventsLocalDataSource();
      mockRemoteDataSource = MockEventsRemoteDataSource();
      repository = EventsRepository(
        localDataSource: mockLocalDataSource,
        remoteDataSource: mockRemoteDataSource,
      );
    });

    // =================================================================
    // getEventsFeed() Tests
    // =================================================================

    group('getEventsFeed', () {
      test('page 1 fetches from remote and caches result', () async {
        // Arrange
        final testEvents = createTestEventsList(count: 3);
        when(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .thenAnswer((_) async => testEvents);
        when(() => mockLocalDataSource.saveEventsToCache(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.getEventsFeed(page: 1, limit: 20);

        // Assert
        expect(result.length, 3);
        expect(result[0].id, 'event-0');
        expect(result[0].title, 'Test Event 0');
        verify(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .called(1);
        verify(() => mockLocalDataSource.saveEventsToCache(testEvents))
            .called(1);
      });

      test('page 2+ fetches from remote but does NOT cache', () async {
        // Arrange
        final testEvents = createTestEventsList(count: 2);
        when(() => mockRemoteDataSource.fetchEventsFeed(page: 2, limit: 20))
            .thenAnswer((_) async => testEvents);

        // Act
        final result = await repository.getEventsFeed(page: 2, limit: 20);

        // Assert
        expect(result.length, 2);
        verify(() => mockRemoteDataSource.fetchEventsFeed(page: 2, limit: 20))
            .called(1);
        verifyNever(() => mockLocalDataSource.saveEventsToCache(any()));
      });

      test('network fail on page 1, fallback to cache', () async {
        // Arrange
        final cachedEvents = createTestEventsList(count: 2);
        when(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .thenThrow(Exception('Network error'));
        when(() => mockLocalDataSource.getCachedEvents())
            .thenAnswer((_) async => cachedEvents);

        // Act
        final result = await repository.getEventsFeed(page: 1, limit: 20);

        // Assert
        expect(result.length, 2);
        expect(result[0].id, 'event-0');
        verify(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .called(1);
        verify(() => mockLocalDataSource.getCachedEvents()).called(1);
      });

      test('network fail on page 1 with no cache, rethrows error', () async {
        // Arrange
        when(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .thenThrow(Exception('Network error'));
        when(() => mockLocalDataSource.getCachedEvents())
            .thenAnswer((_) async => []);

        // Act & Assert
        expect(
          () => repository.getEventsFeed(page: 1, limit: 20),
          throwsA(isA<Exception>()),
        );
        verify(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .called(1);
        verify(() => mockLocalDataSource.getCachedEvents()).called(1);
      });

      test('network fail on page 2+, does NOT fallback to cache', () async {
        // Arrange
        when(() => mockRemoteDataSource.fetchEventsFeed(page: 2, limit: 20))
            .thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () => repository.getEventsFeed(page: 2, limit: 20),
          throwsA(isA<Exception>()),
        );
        verify(() => mockRemoteDataSource.fetchEventsFeed(page: 2, limit: 20))
            .called(1);
        verifyNever(() => mockLocalDataSource.getCachedEvents());
      });

      test('converts EventModel list to Event entities', () async {
        // Arrange
        final testEvents = [
          createTestEventModel(
            id: 'event-1',
            title: 'Event 1',
            status: 'approved',
          ),
        ];
        when(() => mockRemoteDataSource.fetchEventsFeed(page: 1, limit: 20))
            .thenAnswer((_) async => testEvents);
        when(() => mockLocalDataSource.saveEventsToCache(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.getEventsFeed(page: 1, limit: 20);

        // Assert
        expect(result.length, 1);
        expect(result[0].id, 'event-1');
        expect(result[0].title, 'Event 1');
        expect(result[0].status, EventStatus.approved);
      });
    });

    // =================================================================
    // getEventById() Tests
    // =================================================================

    group('getEventById', () {
      test('cache hit when forceRefresh is false', () async {
        // Arrange
        final cachedEvent = createTestEventModel(id: 'cached-event');
        when(() => mockLocalDataSource.getCachedEventById('cached-event'))
            .thenAnswer((_) async => cachedEvent);

        // Act
        final result = await repository.getEventById('cached-event');

        // Assert
        expect(result.id, 'cached-event');
        verify(() => mockLocalDataSource.getCachedEventById('cached-event'))
            .called(1);
        verifyNever(() => mockRemoteDataSource.fetchEventById(any()));
      });

      test('cache miss, fetch from remote', () async {
        // Arrange
        final remoteEvent = createTestEventModel(id: 'remote-event');
        when(() => mockLocalDataSource.getCachedEventById('remote-event'))
            .thenAnswer((_) async => null);
        when(() => mockRemoteDataSource.fetchEventById('remote-event'))
            .thenAnswer((_) async => remoteEvent);
        when(() => mockLocalDataSource.updateEventInCache(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.getEventById('remote-event');

        // Assert
        expect(result.id, 'remote-event');
        verify(() => mockLocalDataSource.getCachedEventById('remote-event'))
            .called(1);
        verify(() => mockRemoteDataSource.fetchEventById('remote-event'))
            .called(1);
        verify(() => mockLocalDataSource.updateEventInCache(remoteEvent))
            .called(1);
      });

      test('forceRefresh bypasses cache and fetches from remote', () async {
        // Arrange
        final remoteEvent = createTestEventModel(id: 'fresh-event');
        when(() => mockRemoteDataSource.fetchEventById('fresh-event'))
            .thenAnswer((_) async => remoteEvent);
        when(() => mockLocalDataSource.updateEventInCache(any()))
            .thenAnswer((_) async => {});

        // Act
        final result =
            await repository.getEventById('fresh-event', forceRefresh: true);

        // Assert
        expect(result.id, 'fresh-event');
        verifyNever(() => mockLocalDataSource.getCachedEventById(any()));
        verify(() => mockRemoteDataSource.fetchEventById('fresh-event'))
            .called(1);
        verify(() => mockLocalDataSource.updateEventInCache(remoteEvent))
            .called(1);
      });

      test('forceRefresh network fail, fallback to cache', () async {
        // Arrange
        final cachedEvent = createTestEventModel(id: 'fallback-event');
        when(() => mockRemoteDataSource.fetchEventById('fallback-event'))
            .thenThrow(Exception('Network error'));
        when(() => mockLocalDataSource.getCachedEventById('fallback-event'))
            .thenAnswer((_) async => cachedEvent);

        // Act
        final result = await repository.getEventById(
          'fallback-event',
          forceRefresh: true,
        );

        // Assert
        expect(result.id, 'fallback-event');
        verify(() => mockRemoteDataSource.fetchEventById('fallback-event'))
            .called(1);
        verify(() => mockLocalDataSource.getCachedEventById('fallback-event'))
            .called(1);
      });

      test('forceRefresh network fail with no cache, rethrows', () async {
        // Arrange
        when(() => mockRemoteDataSource.fetchEventById('no-cache-event'))
            .thenThrow(Exception('Network error'));
        when(() => mockLocalDataSource.getCachedEventById('no-cache-event'))
            .thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => repository.getEventById('no-cache-event', forceRefresh: true),
          throwsA(isA<Exception>()),
        );
      });
    });

    // =================================================================
    // updateEvent() Tests
    // =================================================================

    group('updateEvent', () {
      test('updates event successfully', () async {
        // Arrange
        final updatedEvent = createTestEventModel(
          id: 'event-to-update',
          title: 'Updated Title',
        );
        final updates = {'title': 'Updated Title'};
        when(() => mockRemoteDataSource.updateEvent(
              eventId: 'event-to-update',
              updates: updates,
            )).thenAnswer((_) async => updatedEvent);
        when(() => mockLocalDataSource.updateEventInCache(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.updateEvent(
          eventId: 'event-to-update',
          updates: updates,
        );

        // Assert
        expect(result.id, 'event-to-update');
        expect(result.title, 'Updated Title');
        verify(() => mockRemoteDataSource.updateEvent(
              eventId: 'event-to-update',
              updates: updates,
            )).called(1);
        verify(() => mockLocalDataSource.updateEventInCache(updatedEvent))
            .called(1);
      });

      test('updates cache after remote update', () async {
        // Arrange
        final updatedEvent = createTestEventModel(id: 'event-123');
        final updates = {'description': 'New description'};
        when(() => mockRemoteDataSource.updateEvent(
              eventId: 'event-123',
              updates: updates,
            )).thenAnswer((_) async => updatedEvent);
        when(() => mockLocalDataSource.updateEventInCache(any()))
            .thenAnswer((_) async => {});

        // Act
        await repository.updateEvent(
          eventId: 'event-123',
          updates: updates,
        );

        // Assert
        verify(() => mockLocalDataSource.updateEventInCache(updatedEvent))
            .called(1);
      });
    });

    // =================================================================
    // deleteEvent() Tests
    // =================================================================

    group('deleteEvent', () {
      test('deletes event successfully', () async {
        // Arrange
        when(() => mockRemoteDataSource.deleteEvent('event-to-delete'))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.removeEventFromCache('event-to-delete'))
            .thenAnswer((_) async => {});

        // Act
        await repository.deleteEvent('event-to-delete');

        // Assert
        verify(() => mockRemoteDataSource.deleteEvent('event-to-delete'))
            .called(1);
        verify(() => mockLocalDataSource.removeEventFromCache('event-to-delete'))
            .called(1);
      });

      test('removes event from cache after deletion', () async {
        // Arrange
        when(() => mockRemoteDataSource.deleteEvent('event-456'))
            .thenAnswer((_) async => {});
        when(() => mockLocalDataSource.removeEventFromCache('event-456'))
            .thenAnswer((_) async => {});

        // Act
        await repository.deleteEvent('event-456');

        // Assert
        verify(() => mockLocalDataSource.removeEventFromCache('event-456'))
            .called(1);
      });
    });

    // =================================================================
    // clearCache() Tests
    // =================================================================

    group('clearCache', () {
      test('clears all cached events', () async {
        // Arrange
        when(() => mockLocalDataSource.clearEventsCache())
            .thenAnswer((_) async => {});

        // Act
        await repository.clearCache();

        // Assert
        verify(() => mockLocalDataSource.clearEventsCache()).called(1);
      });
    });

    // =================================================================
    // likeEvent() Tests
    // =================================================================

    group('likeEvent', () {
      test('likes event successfully', () async {
        // Arrange
        when(() => mockRemoteDataSource.likeEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).thenAnswer((_) async => {});

        // Act
        await repository.likeEvent(eventId: 'event-1', userId: 'user-1');

        // Assert
        verify(() => mockRemoteDataSource.likeEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).called(1);
      });
    });

    // =================================================================
    // unlikeEvent() Tests
    // =================================================================

    group('unlikeEvent', () {
      test('unlikes event successfully', () async {
        // Arrange
        when(() => mockRemoteDataSource.unlikeEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).thenAnswer((_) async => {});

        // Act
        await repository.unlikeEvent(eventId: 'event-1', userId: 'user-1');

        // Assert
        verify(() => mockRemoteDataSource.unlikeEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).called(1);
      });
    });

    // =================================================================
    // getLikeCount() Tests
    // =================================================================

    group('getLikeCount', () {
      test('returns like count from remote', () async {
        // Arrange
        when(() => mockRemoteDataSource.getLikeCount('event-1'))
            .thenAnswer((_) async => 42);

        // Act
        final result = await repository.getLikeCount('event-1');

        // Assert
        expect(result, 42);
        verify(() => mockRemoteDataSource.getLikeCount('event-1')).called(1);
      });

      test('returns zero when no likes', () async {
        // Arrange
        when(() => mockRemoteDataSource.getLikeCount('event-2'))
            .thenAnswer((_) async => 0);

        // Act
        final result = await repository.getLikeCount('event-2');

        // Assert
        expect(result, 0);
      });
    });

    // =================================================================
    // hasUserLikedEvent() Tests
    // =================================================================

    group('hasUserLikedEvent', () {
      test('returns true when user has liked event', () async {
        // Arrange
        when(() => mockRemoteDataSource.isEventLiked(
              eventId: 'event-1',
              userId: 'user-1',
            )).thenAnswer((_) async => true);

        // Act
        final result = await repository.hasUserLikedEvent(
          eventId: 'event-1',
          userId: 'user-1',
        );

        // Assert
        expect(result, true);
        verify(() => mockRemoteDataSource.isEventLiked(
              eventId: 'event-1',
              userId: 'user-1',
            )).called(1);
      });

      test('returns false when user has not liked event', () async {
        // Arrange
        when(() => mockRemoteDataSource.isEventLiked(
              eventId: 'event-2',
              userId: 'user-2',
            )).thenAnswer((_) async => false);

        // Act
        final result = await repository.hasUserLikedEvent(
          eventId: 'event-2',
          userId: 'user-2',
        );

        // Assert
        expect(result, false);
      });
    });

    // =================================================================
    // participateInEvent() Tests
    // =================================================================

    group('participateInEvent', () {
      test('participates in event successfully', () async {
        // Arrange
        when(() => mockRemoteDataSource.participateInEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).thenAnswer((_) async => {});

        // Act
        await repository.participateInEvent(
          eventId: 'event-1',
          userId: 'user-1',
        );

        // Assert
        verify(() => mockRemoteDataSource.participateInEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).called(1);
      });
    });

    // =================================================================
    // unparticipateFromEvent() Tests
    // =================================================================

    group('unparticipateFromEvent', () {
      test('unparticipates from event successfully', () async {
        // Arrange
        when(() => mockRemoteDataSource.unparticipateFromEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).thenAnswer((_) async => {});

        // Act
        await repository.unparticipateFromEvent(
          eventId: 'event-1',
          userId: 'user-1',
        );

        // Assert
        verify(() => mockRemoteDataSource.unparticipateFromEvent(
              eventId: 'event-1',
              userId: 'user-1',
            )).called(1);
      });
    });

    // =================================================================
    // getParticipationCount() Tests
    // =================================================================

    group('getParticipationCount', () {
      test('returns participation count from remote', () async {
        // Arrange
        when(() => mockRemoteDataSource.getParticipantCount('event-1'))
            .thenAnswer((_) async => 15);

        // Act
        final result = await repository.getParticipationCount('event-1');

        // Assert
        expect(result, 15);
        verify(() => mockRemoteDataSource.getParticipantCount('event-1'))
            .called(1);
      });

      test('returns zero when no participants', () async {
        // Arrange
        when(() => mockRemoteDataSource.getParticipantCount('event-2'))
            .thenAnswer((_) async => 0);

        // Act
        final result = await repository.getParticipationCount('event-2');

        // Assert
        expect(result, 0);
      });
    });

    // =================================================================
    // isUserParticipating() Tests
    // =================================================================

    group('isUserParticipating', () {
      test('returns true when user is participating', () async {
        // Arrange
        when(() => mockRemoteDataSource.isParticipating(
              eventId: 'event-1',
              userId: 'user-1',
            )).thenAnswer((_) async => true);

        // Act
        final result = await repository.isUserParticipating(
          eventId: 'event-1',
          userId: 'user-1',
        );

        // Assert
        expect(result, true);
        verify(() => mockRemoteDataSource.isParticipating(
              eventId: 'event-1',
              userId: 'user-1',
            )).called(1);
      });

      test('returns false when user is not participating', () async {
        // Arrange
        when(() => mockRemoteDataSource.isParticipating(
              eventId: 'event-2',
              userId: 'user-2',
            )).thenAnswer((_) async => false);

        // Act
        final result = await repository.isUserParticipating(
          eventId: 'event-2',
          userId: 'user-2',
        );

        // Assert
        expect(result, false);
      });
    });

    // =================================================================
    // getEventComments() Tests (UnimplementedError)
    // =================================================================

    group('getEventComments', () {
      test('throws UnimplementedError', () async {
        // Act & Assert
        expect(
          () => repository.getEventComments('event-1'),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });

    // =================================================================
    // postComment() Tests (UnimplementedError)
    // =================================================================

    group('postComment', () {
      test('throws UnimplementedError', () async {
        // Act & Assert
        expect(
          () => repository.postComment(
            eventId: 'event-1',
            userId: 'user-1',
            content: 'Test comment',
          ),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });

    // =================================================================
    // reportEvent() Tests (UnimplementedError)
    // =================================================================

    group('reportEvent', () {
      test('throws UnimplementedError', () async {
        // Act & Assert
        expect(
          () => repository.reportEvent(
            eventId: 'event-1',
            userId: 'user-1',
            reason: 'spam',
            explanation: 'This is spam',
          ),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });
  });
}
