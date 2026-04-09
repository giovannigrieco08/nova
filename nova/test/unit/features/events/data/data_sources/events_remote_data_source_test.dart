import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/events/data/data_sources/events_remote_data_source.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/data/models/comment_model.dart';

import '../../../../../mocks/mock_supabase.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const _testEventId = 'event-123';
const _testUserId = 'user-456';
const _testCommentId = 'comment-789';

Map<String, dynamic> _eventJson({String id = _testEventId}) => {
      'id': id,
      'title': 'Test Event',
      'description': 'A test event',
      'event_date': '2026-05-01T18:00:00.000Z',
      'location': 'Aula Magna',
      'image_url': null,
      'creator_id': _testUserId,
      'co_organizers': <String>[],
      'status': 'approved',
      'rejection_reason': null,
      'moderated_by': null,
      'moderated_at': null,
      'created_at': '2026-04-01T10:00:00.000Z',
      'updated_at': '2026-04-01T10:00:00.000Z',
      'latitude': null,
      'longitude': null,
      'place_id': null,
      'creator': {
        'user_id': _testUserId,
        'full_name': 'Mario Rossi',
        'avatar_url': null,
        'class': '3A',
      },
    };

Map<String, dynamic> _commentJson({String id = _testCommentId}) => {
      'id': id,
      'event_id': _testEventId,
      'user_id': _testUserId,
      'text': 'Great event!',
      'created_at': '2026-04-02T12:00:00.000Z',
      'author': {
        'user_id': _testUserId,
        'full_name': 'Mario Rossi',
        'avatar_url': null,
        'class': '3A',
      },
    };

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets up `mockSupabase.from(table)` to return [mockQb].
void _stubFrom(
  MockSupabaseClient mockSupabase,
  MockSupabaseQueryBuilder mockQb,
  String table,
) {
  when(() => mockSupabase.from(table)).thenAnswer((_) => mockQb);
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQb;
  late EventsRemoteDataSource dataSource;

  setUpAll(() {
    ensureMockFallbacks();
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQb = MockSupabaseQueryBuilder();
    dataSource = EventsRemoteDataSource(supabase: mockSupabase);
  });

  // =========================================================================
  // fetchEventsFeed
  // =========================================================================

  group('fetchEventsFeed', () {
    test('returns list of EventModel on success', () async {
      final fb = mockListQuery([_eventJson()]);
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchEventsFeed(page: 1, limit: 10);

      expect(result, isA<List<EventModel>>());
      expect(result.length, 1);
      expect(result.first.id, _testEventId);
    });

    test('returns empty list when no events', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchEventsFeed(page: 1, limit: 10);

      expect(result, isEmpty);
    });

    test('throws on Supabase error', () async {
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenThrow(Exception('network error'));

      expect(
        () => dataSource.fetchEventsFeed(page: 1, limit: 10),
        throwsException,
      );
    });
  });

  // =========================================================================
  // fetchEventById
  // =========================================================================

  group('fetchEventById', () {
    test('returns EventModel on success', () async {
      final fb = mockSingleQuery(_eventJson());
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchEventById(_testEventId);

      expect(result, isA<EventModel>());
      expect(result.title, 'Test Event');
    });

    test('throws on Supabase error', () async {
      final fb = mockListQuery([_eventJson()]);
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);
      when(() => fb.single()).thenThrow(Exception('not found'));

      expect(
        () => dataSource.fetchEventById(_testEventId),
        throwsException,
      );
    });
  });

  // =========================================================================
  // updateEvent
  // =========================================================================

  group('updateEvent', () {
    test('returns updated EventModel on success', () async {
      final fb = mockSingleQuery(_eventJson());
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      final result = await dataSource.updateEvent(
        eventId: _testEventId,
        updates: {'title': 'Updated'},
      );

      expect(result, isA<EventModel>());
    });

    test('throws on Supabase error', () async {
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.update(any())).thenThrow(Exception('forbidden'));

      expect(
        () => dataSource.updateEvent(
          eventId: _testEventId,
          updates: {'title': 'X'},
        ),
        throwsException,
      );
    });
  });

  // =========================================================================
  // deleteEvent
  // =========================================================================

  group('deleteEvent', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.deleteEvent(_testEventId),
        completes,
      );
    });

    test('throws on Supabase error', () async {
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.delete()).thenThrow(Exception('forbidden'));

      expect(
        () => dataSource.deleteEvent(_testEventId),
        throwsException,
      );
    });
  });

  // =========================================================================
  // likeEvent / unlikeEvent
  // =========================================================================

  group('likeEvent', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'likes');
      when(() => mockQb.upsert(
            any(),
            onConflict: any(named: 'onConflict'),
            ignoreDuplicates: any(named: 'ignoreDuplicates'),
          )).thenAnswer((_) => fb);

      await expectLater(
        dataSource.likeEvent(eventId: _testEventId, userId: _testUserId),
        completes,
      );
    });
  });

  group('unlikeEvent', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'likes');
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.unlikeEvent(eventId: _testEventId, userId: _testUserId),
        completes,
      );
    });
  });

  // =========================================================================
  // getLikeCount / isEventLiked
  // =========================================================================

  group('getLikeCount', () {
    test('returns count of likes', () async {
      final fb = mockListQuery([
        {'event_id': _testEventId, 'user_id': 'u1'},
        {'event_id': _testEventId, 'user_id': 'u2'},
      ]);
      _stubFrom(mockSupabase, mockQb, 'likes');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final count = await dataSource.getLikeCount(_testEventId);

      expect(count, 2);
    });
  });

  group('isEventLiked', () {
    test('returns true when liked', () async {
      final fb = mockListQuery([
        {'event_id': _testEventId, 'user_id': _testUserId},
      ]);
      _stubFrom(mockSupabase, mockQb, 'likes');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.isEventLiked(
        eventId: _testEventId,
        userId: _testUserId,
      );

      expect(result, isTrue);
    });

    test('returns false when not liked', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      _stubFrom(mockSupabase, mockQb, 'likes');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.isEventLiked(
        eventId: _testEventId,
        userId: _testUserId,
      );

      expect(result, isFalse);
    });
  });

  // =========================================================================
  // participateInEvent / unparticipateFromEvent
  // =========================================================================

  group('participateInEvent', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'participations');
      when(() => mockQb.upsert(
            any(),
            onConflict: any(named: 'onConflict'),
            ignoreDuplicates: any(named: 'ignoreDuplicates'),
          )).thenAnswer((_) => fb);

      await expectLater(
        dataSource.participateInEvent(
          eventId: _testEventId,
          userId: _testUserId,
        ),
        completes,
      );
    });
  });

  group('unparticipateFromEvent', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'participations');
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.unparticipateFromEvent(
          eventId: _testEventId,
          userId: _testUserId,
        ),
        completes,
      );
    });
  });

  // =========================================================================
  // getParticipants
  // =========================================================================

  group('getParticipants', () {
    test('returns profiles for participants', () async {
      // Step 1: participations query
      final participationsFb = mockListQuery([
        {'user_id': 'u1'},
        {'user_id': 'u2'},
      ]);
      // Step 2: profiles query
      final profilesFb = mockListQuery([
        {'user_id': 'u1', 'full_name': 'Alice', 'avatar_url': null, 'class': '3A'},
        {'user_id': 'u2', 'full_name': 'Bob', 'avatar_url': null, 'class': '4B'},
      ]);

      final qb1 = MockSupabaseQueryBuilder();
      final qb2 = MockSupabaseQueryBuilder();

      // First call: from('participations'), second call: from('profiles')
      var callCount = 0;
      when(() => mockSupabase.from(any())).thenAnswer((invocation) {
        callCount++;
        if (callCount == 1) return qb1;
        return qb2;
      });
      when(() => qb1.select(any())).thenAnswer((_) => participationsFb);
      when(() => qb2.select(any())).thenAnswer((_) => profilesFb);

      final result = await dataSource.getParticipants(_testEventId);

      expect(result.length, 2);
      expect(result.first['full_name'], 'Alice');
    });

    test('returns empty list when no participants', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      _stubFrom(mockSupabase, mockQb, 'participations');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.getParticipants(_testEventId);

      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // getParticipantCount / isParticipating
  // =========================================================================

  group('getParticipantCount', () {
    test('returns correct count', () async {
      final fb = mockListQuery([
        {'event_id': _testEventId, 'user_id': 'u1'},
      ]);
      _stubFrom(mockSupabase, mockQb, 'participations');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final count = await dataSource.getParticipantCount(_testEventId);

      expect(count, 1);
    });
  });

  group('isParticipating', () {
    test('returns true when participating', () async {
      final fb = mockListQuery([
        {'event_id': _testEventId, 'user_id': _testUserId},
      ]);
      _stubFrom(mockSupabase, mockQb, 'participations');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.isParticipating(
        eventId: _testEventId,
        userId: _testUserId,
      );

      expect(result, isTrue);
    });
  });

  // =========================================================================
  // fetchEventsByCreator / fetchUserPendingEvents
  // =========================================================================

  group('fetchEventsByCreator', () {
    test('returns events created by user', () async {
      final fb = mockListQuery([_eventJson()]);
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchEventsByCreator(_testUserId);

      expect(result.length, 1);
      expect(result.first.creatorId, _testUserId);
    });
  });

  group('fetchUserPendingEvents', () {
    test('returns pending events for user', () async {
      final pendingEvent = _eventJson()..['status'] = 'pending';
      final fb = mockListQuery([pendingEvent]);
      _stubFrom(mockSupabase, mockQb, 'events');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchUserPendingEvents(_testUserId);

      expect(result.length, 1);
    });
  });

  // =========================================================================
  // fetchEventsParticipating
  // =========================================================================

  group('fetchEventsParticipating', () {
    test('returns events user participates in', () async {
      final participationsFb = mockListQuery([
        {'event_id': _testEventId},
      ]);
      final eventsFb = mockListQuery([_eventJson()]);

      final qb1 = MockSupabaseQueryBuilder();
      final qb2 = MockSupabaseQueryBuilder();

      var callCount = 0;
      when(() => mockSupabase.from(any())).thenAnswer((_) {
        callCount++;
        if (callCount == 1) return qb1;
        return qb2;
      });
      when(() => qb1.select(any())).thenAnswer((_) => participationsFb);
      when(() => qb2.select(any())).thenAnswer((_) => eventsFb);

      final result = await dataSource.fetchEventsParticipating(_testUserId);

      expect(result.length, 1);
      expect(result.first.id, _testEventId);
    });

    test('returns empty list when no participations', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      _stubFrom(mockSupabase, mockQb, 'participations');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchEventsParticipating(_testUserId);

      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // fetchComments / postComment / deleteComment / getCommentCount
  // =========================================================================

  group('fetchComments', () {
    test('returns list of CommentModel on success', () async {
      final fb = mockListQuery([_commentJson()]);
      _stubFrom(mockSupabase, mockQb, 'comments');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.fetchComments(_testEventId);

      expect(result, isA<List<CommentModel>>());
      expect(result.length, 1);
      expect(result.first.content, 'Great event!');
    });
  });

  group('postComment', () {
    test('returns CommentModel on success', () async {
      final fb = mockSingleQuery(_commentJson());
      _stubFrom(mockSupabase, mockQb, 'comments');
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.postComment(
        eventId: _testEventId,
        authorId: _testUserId,
        text: 'Great event!',
      );

      expect(result, isA<CommentModel>());
    });

    test('throws when text is empty', () async {
      expect(
        () => dataSource.postComment(
          eventId: _testEventId,
          authorId: _testUserId,
          text: '   ',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('empty'),
        )),
      );
    });

    test('throws when text exceeds 500 characters', () async {
      expect(
        () => dataSource.postComment(
          eventId: _testEventId,
          authorId: _testUserId,
          text: 'a' * 501,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('500'),
        )),
      );
    });
  });

  group('deleteComment', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'comments');
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.deleteComment(_testCommentId),
        completes,
      );
    });
  });

  group('getCommentCount', () {
    test('returns correct count', () async {
      final fb = mockListQuery([_commentJson(), _commentJson(id: 'c2')]);
      _stubFrom(mockSupabase, mockQb, 'comments');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final count = await dataSource.getCommentCount(_testEventId);

      expect(count, 2);
    });
  });

  // =========================================================================
  // submitReport
  // =========================================================================

  group('submitReport', () {
    test('completes without error for valid reason', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'reports');
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.submitReport(
          eventId: _testEventId,
          reporterId: _testUserId,
          reason: 'spam',
          explanation: 'This is spam',
        ),
        completes,
      );
    });

    test('throws for invalid reason', () async {
      expect(
        () => dataSource.submitReport(
          eventId: _testEventId,
          reporterId: _testUserId,
          reason: 'invalid_reason',
          explanation: 'test',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid report reason'),
        )),
      );
    });
  });

  // =========================================================================
  // Help requests
  // =========================================================================

  group('fetchHelpRequests', () {
    test('returns list of help requests', () async {
      final fb = mockListQuery([
        {'id': 'hr-1', 'event_id': _testEventId, 'description': 'Need help'},
      ]);
      _stubFrom(mockSupabase, mockQb, 'event_help_requests');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.fetchHelpRequests(_testEventId);

      expect(result.length, 1);
      expect(result.first['description'], 'Need help');
    });
  });

  group('createHelpRequest', () {
    test('returns created help request', () async {
      final data = {
        'id': 'hr-1',
        'event_id': _testEventId,
        'description': 'Need speakers',
      };
      final fb = mockSingleQuery(data);
      _stubFrom(mockSupabase, mockQb, 'event_help_requests');
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.createHelpRequest(
        eventId: _testEventId,
        description: 'Need speakers',
      );

      expect(result['id'], 'hr-1');
    });
  });

  group('deleteHelpRequest', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'event_help_requests');
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.deleteHelpRequest('hr-1'),
        completes,
      );
    });
  });

  // =========================================================================
  // Help offers
  // =========================================================================

  group('createHelpOffer', () {
    test('returns created offer', () async {
      final data = {
        'id': 'ho-1',
        'request_id': 'hr-1',
        'user_id': _testUserId,
        'message': 'I can help',
        'status': 'pending',
        'profile': {
          'user_id': _testUserId,
          'full_name': 'Mario',
          'avatar_url': null,
          'class': '3A',
        },
      };
      final fb = mockSingleQuery(data);
      _stubFrom(mockSupabase, mockQb, 'event_help_offers');
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await dataSource.createHelpOffer(
        requestId: 'hr-1',
        userId: _testUserId,
        message: 'I can help',
      );

      expect(result['id'], 'ho-1');
    });
  });

  group('hasUserOfferedHelp', () {
    test('returns true when user has offered', () async {
      final fb = mockListQuery([
        {'id': 'ho-1', 'request_id': 'hr-1', 'user_id': _testUserId},
      ]);
      _stubFrom(mockSupabase, mockQb, 'event_help_offers');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.hasUserOfferedHelp(
        requestId: 'hr-1',
        userId: _testUserId,
      );

      expect(result, isTrue);
    });

    test('returns false when user has not offered', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      _stubFrom(mockSupabase, mockQb, 'event_help_offers');
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.hasUserOfferedHelp(
        requestId: 'hr-1',
        userId: _testUserId,
      );

      expect(result, isFalse);
    });
  });

  // =========================================================================
  // Event reports (event_reports table)
  // =========================================================================

  group('reportEvent', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'event_reports');
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.reportEvent(
          eventId: _testEventId,
          reporterId: _testUserId,
          reason: 'spam',
        ),
        completes,
      );
    });
  });

  group('hasUserReportedEvent', () {
    test('returns true when reported', () async {
      final fb = mockListQuery([
        {'id': 'rpt-1'},
      ]);
      _stubFrom(mockSupabase, mockQb, 'event_reports');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.hasUserReportedEvent(
        eventId: _testEventId,
        userId: _testUserId,
      );

      expect(result, isTrue);
    });

    test('returns false when not reported', () async {
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      _stubFrom(mockSupabase, mockQb, 'event_reports');
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await dataSource.hasUserReportedEvent(
        eventId: _testEventId,
        userId: _testUserId,
      );

      expect(result, isFalse);
    });
  });

  // =========================================================================
  // respondToInvitation / cancelInvitation
  // =========================================================================

  group('respondToInvitation', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'event_invitations');
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.respondToInvitation(
          invitationId: 'inv-1',
          status: 'accepted',
        ),
        completes,
      );
    });
  });

  group('cancelInvitation', () {
    test('completes without error', () async {
      final fb = mockVoidQuery();
      _stubFrom(mockSupabase, mockQb, 'event_invitations');
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      await expectLater(
        dataSource.cancelInvitation('inv-1'),
        completes,
      );
    });
  });
}
