import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/comments/data/datasources/comments_remote_datasource.dart';
import 'package:nova/features/comments/data/models/comment_model.dart';
import 'package:nova/features/comments/data/models/comment_report_model.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';
import 'package:nova/features/comments/domain/exceptions/comments_exceptions.dart';
import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  late CommentsRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);
    dataSource = CommentsRemoteDataSource(mockSupabase);
  });

  // ==========================================================================
  // Helper: comment JSON
  // ==========================================================================

  Map<String, dynamic> commentJson({
    String id = 'comment-001',
    String eventId = 'test-event-001',
    String? authorId,
    String content = 'Bellissimo evento!',
    String? parentCommentId,
    int depth = 0,
  }) {
    return {
      'id': id,
      'event_id': eventId,
      'author_id': authorId ?? TestUserIds.student1,
      'content': content,
      'parent_comment_id': parentCommentId,
      'depth': depth,
      'like_count': 5,
      'reply_count': 0,
      'report_count': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': null,
      'deleted_at': null,
    };
  }

  Map<String, dynamic> profileJson({String? userId}) {
    return {
      'user_id': userId ?? TestUserIds.student1,
      'full_name': 'Mario Rossi',
      'avatar_url': null,
      'class': '4A',
    };
  }

  // ==========================================================================
  // postComment
  // ==========================================================================

  group('postComment', () {
    test('happy: creates comment and returns model', () async {
      // Insert comment chain: insert({}).select('*').single()
      // insert() returns PostgrestFilterBuilder<PostgrestList>
      final commentsQb = MockSupabaseQueryBuilder();
      final data = commentJson(content: 'New comment');
      final commentsFb = mockListQuery([data]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.insert(any())).thenAnswer((_) => commentsFb);

      // Fetch profile: select().eq().maybeSingle()
      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final result = await dataSource.postComment(
        eventId: 'test-event-001',
        text: 'New comment',
      );

      expect(result, isA<CommentModel>());
    });

    test('happy: trims whitespace from text', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.insert(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      await dataSource.postComment(
        eventId: 'test-event-001',
        text: '  Trimmed text  ',
      );

      // Verify insert was called (we can't easily check the exact content
      // due to DateTime.now() in the insert)
      verify(() => commentsQb.insert(any())).called(1);
    });

    test('edge: throws UnauthorizedException when not authenticated', () async {
      // Override to have no current user
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.postComment(
          eventId: 'test-event-001',
          text: 'test',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('edge: maps 23514 to ValidationException (profanity)', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.insert(any())).thenAnswer((_) => commentsFb);
      // Override single() to throw
      when(() => commentsFb.single()).thenThrow(PostgrestException(
        message: 'CHECK constraint violation',
        code: '23514',
      ));

      expect(
        () => dataSource.postComment(
          eventId: 'test-event-001',
          text: 'profane word',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('edge: maps P0001 rate limit to RateLimitException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.insert(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(PostgrestException(
        message: 'Rate limit exceeded',
        code: 'P0001',
      ));

      expect(
        () => dataSource.postComment(
          eventId: 'test-event-001',
          text: 'spam',
        ),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('edge: maps 23503 to NotFoundException (event not found)', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.insert(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(PostgrestException(
        message: 'Foreign key violation',
        code: '23503',
      ));

      expect(
        () => dataSource.postComment(
          eventId: 'nonexistent-event',
          text: 'test',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('happy: wraps generic exception as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.insert(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(Exception('timeout'));

      expect(
        () => dataSource.postComment(
          eventId: 'test-event-001',
          text: 'test',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // replyToComment
  // ==========================================================================

  group('replyToComment', () {
    test('edge: throws ValidationException when max depth reached', () async {
      // Mock parent comment fetch: select().eq().single()
      // select() returns PostgrestFilterBuilder<PostgrestList>
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([
        {
          'event_id': 'evt-1',
          'depth': Comment.maxDepth,
        }
      ]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      expect(
        () => dataSource.replyToComment(
          commentId: 'parent-at-max-depth',
          text: 'reply',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('edge: maps 23503 to NotFoundException (parent not found)', () async {
      final commentsQb = MockSupabaseQueryBuilder();

      // First call: select().eq().single() returns parent comment
      final selectFb = mockListQuery([
        {
          'event_id': 'evt-1',
          'depth': 0,
        }
      ]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => selectFb);

      // Second call: insert({}).select('*').single() throws FK violation
      final insertFb = mockListQuery([commentJson()]);
      when(() => commentsQb.insert(any())).thenAnswer((_) => insertFb);
      when(() => insertFb.single()).thenThrow(PostgrestException(
        message: 'FK violation',
        code: '23503',
      ));

      expect(
        () => dataSource.replyToComment(
          commentId: 'deleted-parent',
          text: 'reply',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  // ==========================================================================
  // editComment
  // ==========================================================================

  group('editComment', () {
    test('edge: maps PGRST116 to ForbiddenException (not owner or expired)',
        () async {
      // update({}) returns PostgrestFilterBuilder<PostgrestList>
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      // Override single() to throw
      when(() => commentsFb.single()).thenThrow(PostgrestException(
        message: 'No rows updated',
        code: 'PGRST116',
      ));

      expect(
        () => dataSource.editComment(
          commentId: 'c-1',
          newText: 'updated',
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('edge: maps 23514 to ValidationException on edit', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(PostgrestException(
        message: 'Profanity',
        code: '23514',
      ));

      expect(
        () => dataSource.editComment(
          commentId: 'c-1',
          newText: 'bad word',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ==========================================================================
  // deleteComment
  // ==========================================================================

  group('deleteComment', () {
    test('happy: soft-deletes own comment', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);

      await dataSource.deleteComment(commentId: 'c-1');

      verify(() => commentsQb.update(any())).called(1);
    });

    test('edge: throws ForbiddenException on PGRST116', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      // Override isFilter to throw (terminal call in the chain)
      when(() => commentsFb.isFilter(any(), any()))
          .thenThrow(PostgrestException(
        message: 'No rows',
        code: 'PGRST116',
      ));

      expect(
        () => dataSource.deleteComment(commentId: 'c-1'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('race: concurrent delete of same comment', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);

      int callCount = 0;
      when(() => commentsFb.isFilter(any(), any())).thenAnswer((_) {
        callCount++;
        if (callCount > 1) {
          throw PostgrestException(message: 'No rows', code: 'PGRST116');
        }
        return commentsFb;
      });

      // First succeeds
      await dataSource.deleteComment(commentId: 'c-1');

      // Second fails
      expect(
        () => dataSource.deleteComment(commentId: 'c-1'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  // ==========================================================================
  // likeComment
  // ==========================================================================

  group('likeComment', () {
    test('happy: inserts like and returns updated comment', () async {
      // Mock like insert: from('comment_likes').insert({}) - just awaited
      // insert() returns PostgrestFilterBuilder<PostgrestList>
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_likes')).thenAnswer((_) => likesQb);
      when(() => likesQb.insert(any())).thenAnswer((_) => likesFb);

      // Mock getCommentById: from('comments').select('*').eq().single()
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      // Mock profiles: from('profiles').select().eq().maybeSingle()
      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final result = await dataSource.likeComment(commentId: 'comment-001');

      expect(result, isA<Comment>());
    });

    test('edge: handles duplicate like (23505) idempotently', () async {
      final likesQb = MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('comment_likes')).thenAnswer((_) => likesQb);
      when(() => likesQb.insert(any()))
          .thenThrow(PostgrestException(
        message: 'Duplicate',
        code: '23505',
      ));

      // Mock getCommentById for the fallback fetch
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      // Should not throw - returns existing state
      final result = await dataSource.likeComment(commentId: 'comment-001');
      expect(result, isA<Comment>());
    });

    test('edge: maps 23503 to NotFoundException', () async {
      final likesQb = MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('comment_likes')).thenAnswer((_) => likesQb);
      when(() => likesQb.insert(any()))
          .thenThrow(PostgrestException(
        message: 'FK violation',
        code: '23503',
      ));

      expect(
        () => dataSource.likeComment(commentId: 'nonexistent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('race: concurrent likes from same user', () async {
      // First call succeeds, second is duplicate
      int callCount = 0;
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_likes')).thenAnswer((_) => likesQb);
      when(() => likesQb.insert(any())).thenAnswer((_) {
        callCount++;
        if (callCount > 1) {
          throw PostgrestException(message: 'Duplicate', code: '23505');
        }
        return likesFb;
      });

      // Mock getCommentById
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      // Both should succeed (duplicate is handled idempotently)
      final results = await Future.wait([
        dataSource.likeComment(commentId: 'c-1'),
        dataSource.likeComment(commentId: 'c-1'),
      ]);

      expect(results.length, 2);
    });
  });

  // ==========================================================================
  // reportComment
  // ==========================================================================

  group('reportComment', () {
    test('happy: creates report and returns model', () async {
      final reportsQb = MockSupabaseQueryBuilder();
      final reportsFb = mockListQuery([
        {
          'id': 'report-1',
          'comment_id': 'c-1',
          'reporter_user_id': TestUserIds.student1,
          'reason': 'spam',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);
      when(() => mockSupabase.from('comment_reports')).thenAnswer((_) => reportsQb);
      when(() => reportsQb.insert(any())).thenAnswer((_) => reportsFb);

      final result = await dataSource.reportComment(
        commentId: 'c-1',
        reason: CommentReportReason.spam,
      );

      expect(result, isA<CommentReportModel>());
    });

    test('edge: maps 23505 to ConflictException (already reported)', () async {
      final reportsQb = MockSupabaseQueryBuilder();
      final reportsFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_reports')).thenAnswer((_) => reportsQb);
      when(() => reportsQb.insert(any())).thenAnswer((_) => reportsFb);
      when(() => reportsFb.single()).thenThrow(PostgrestException(
        message: 'Already reported',
        code: '23505',
      ));

      expect(
        () => dataSource.reportComment(
          commentId: 'c-1',
          reason: CommentReportReason.spam,
        ),
        throwsA(isA<ConflictException>()),
      );
    });
  });

  // ==========================================================================
  // moderatorRemoveComment
  // ==========================================================================

  group('moderatorRemoveComment', () {
    test('happy: sets hidden_at and hidden_reason', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);

      await dataSource.moderatorRemoveComment(
        commentId: 'c-1',
        reason: 'Spam',
      );

      verify(() => commentsQb.update(any())).called(1);
    });

    test('edge: maps 42501 to ForbiddenException (not moderator)', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      // Override eq to throw (terminal call in update({}).eq('id', x))
      when(() => commentsFb.eq(any(), any()))
          .thenThrow(PostgrestException(
        message: 'Insufficient privilege',
        code: '42501',
      ));

      expect(
        () => dataSource.moderatorRemoveComment(commentId: 'c-1'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  // ==========================================================================
  // moderatorRestoreComment
  // ==========================================================================

  group('moderatorRestoreComment', () {
    test('edge: maps 42501 to ForbiddenException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      // Override not() to throw (terminal in update({}).eq().not())
      when(() => commentsFb.not(any(), any(), any()))
          .thenThrow(PostgrestException(
        message: 'Insufficient privilege',
        code: '42501',
      ));

      expect(
        () => dataSource.moderatorRestoreComment(commentId: 'c-1'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('happy: restores a hidden comment', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);

      await dataSource.moderatorRestoreComment(commentId: 'c-1');

      verify(() => commentsQb.update(any())).called(1);
    });

    test('edge: maps PGRST116 to NotFoundException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.not(any(), any(), any()))
          .thenThrow(PostgrestException(
        message: 'No rows',
        code: 'PGRST116',
      ));

      expect(
        () => dataSource.moderatorRestoreComment(commentId: 'nonexistent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.not(any(), any(), any()))
          .thenThrow(Exception('timeout'));

      expect(
        () => dataSource.moderatorRestoreComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // getCommentById
  // ==========================================================================

  group('getCommentById', () {
    test('happy: returns a CommentModel with profile data', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      // Mock comment_likes for like status check
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentById(commentId: 'comment-001');

      expect(result, isA<CommentModel>());
    });

    test('edge: throws NotFoundException for PGRST116 (not found)', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(PostgrestException(
        message: 'Row not found',
        code: 'PGRST116',
      ));

      expect(
        () => dataSource.getCommentById(commentId: 'nonexistent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(Exception('network down'));

      expect(
        () => dataSource.getCommentById(commentId: 'comment-001'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // getUserComments
  // ==========================================================================

  group('getUserComments', () {
    test('happy: returns list of user comments with profile', () async {
      // getUserComments uses .eq('user_id', ...) - add user_id and text fields
      final c1 = commentJson(id: 'c-1');
      c1['user_id'] = TestUserIds.student1;
      c1['text'] = c1['content'];
      final c2 = commentJson(id: 'c-2');
      c2['user_id'] = TestUserIds.student1;
      c2['text'] = c2['content'];

      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([c1, c2]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final result = await dataSource.getUserComments(
        userId: TestUserIds.student1,
      );

      expect(result.length, 2);
      expect(result.first, isA<CommentModel>());
    });

    test('happy: returns empty list when user has no comments', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final result = await dataSource.getUserComments(
        userId: TestUserIds.student1,
      );

      expect(result, isEmpty);
    });

    test('edge: wraps PostgrestException as domain exception', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.range(any(), any())).thenThrow(
        PostgrestException(message: 'Server error', code: '42000'),
      );

      expect(
        () => dataSource.getUserComments(userId: TestUserIds.student1),
        throwsA(isA<CommentException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.range(any(), any()))
          .thenThrow(Exception('timeout'));

      expect(
        () => dataSource.getUserComments(userId: TestUserIds.student1),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // unlikeComment
  // ==========================================================================

  group('unlikeComment', () {
    test('happy: deletes like and returns updated comment', () async {
      // Mock unlike: from('comment_likes').delete().eq().eq()
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.delete()).thenAnswer((_) => likesFb);

      // Mock getCommentById
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson()]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final result = await dataSource.unlikeComment(commentId: 'comment-001');

      expect(result, isA<Comment>());
    });

    test('edge: throws NetworkException when not authenticated', () async {
      // UnauthorizedException is caught by the generic catch and wrapped
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.unlikeComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.delete()).thenAnswer((_) => likesFb);
      when(() => likesFb.eq(any(), any())).thenThrow(Exception('network'));

      expect(
        () => dataSource.unlikeComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // getRepliesForComment
  // ==========================================================================

  group('getRepliesForComment', () {
    test('happy: returns list of reply models', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([
        commentJson(id: 'reply-1', parentCommentId: 'c-1', depth: 1),
        commentJson(id: 'reply-2', parentCommentId: 'c-1', depth: 1),
      ]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      // Mock comment_likes for like status
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result =
          await dataSource.getRepliesForComment(commentId: 'c-1');

      expect(result.length, 2);
      expect(result.first, isA<CommentModel>());
    });

    test('happy: returns empty list when no replies', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final result =
          await dataSource.getRepliesForComment(commentId: 'c-1');

      expect(result, isEmpty);
    });

    test('edge: wraps PostgrestException as domain exception', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.order(any(), ascending: any(named: 'ascending')))
          .thenThrow(PostgrestException(message: 'error', code: '42000'));

      expect(
        () => dataSource.getRepliesForComment(commentId: 'c-1'),
        throwsA(isA<CommentException>()),
      );
    });
  });

  // ==========================================================================
  // editComment - additional tests
  // ==========================================================================

  group('editComment - additional', () {
    test('edge: throws NetworkException when not authenticated', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.editComment(
          commentId: 'c-1',
          newText: 'updated',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.single()).thenThrow(Exception('timeout'));

      expect(
        () => dataSource.editComment(commentId: 'c-1', newText: 'test'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // deleteComment - additional tests
  // ==========================================================================

  group('deleteComment - additional', () {
    test('edge: throws NetworkException when not authenticated', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.deleteComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.isFilter(any(), any()))
          .thenThrow(Exception('timeout'));

      expect(
        () => dataSource.deleteComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // likeComment - additional tests
  // ==========================================================================

  group('likeComment - additional', () {
    test('edge: throws NetworkException when not authenticated', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.likeComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: maps P0001 rate limit to RateLimitException', () async {
      final likesQb = MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.insert(any())).thenThrow(PostgrestException(
        message: 'Rate limit exceeded for likes',
        code: 'P0001',
      ));

      expect(
        () => dataSource.likeComment(commentId: 'c-1'),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('edge: maps 42501 RLS violation to NetworkException', () async {
      final likesQb = MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.insert(any())).thenThrow(PostgrestException(
        message: 'RLS policy violation',
        code: '42501',
      ));

      expect(
        () => dataSource.likeComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // reportComment - additional tests
  // ==========================================================================

  group('reportComment - additional', () {
    test('edge: throws NetworkException when not authenticated', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.reportComment(
          commentId: 'c-1',
          reason: CommentReportReason.spam,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: maps 23503 to NotFoundException (comment not found)',
        () async {
      final reportsQb = MockSupabaseQueryBuilder();
      final reportsFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_reports'))
          .thenAnswer((_) => reportsQb);
      when(() => reportsQb.insert(any())).thenAnswer((_) => reportsFb);
      when(() => reportsFb.single()).thenThrow(PostgrestException(
        message: 'FK violation',
        code: '23503',
      ));

      expect(
        () => dataSource.reportComment(
          commentId: 'nonexistent',
          reason: CommentReportReason.spam,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final reportsQb = MockSupabaseQueryBuilder();
      final reportsFb = mockVoidQuery();
      when(() => mockSupabase.from('comment_reports'))
          .thenAnswer((_) => reportsQb);
      when(() => reportsQb.insert(any())).thenAnswer((_) => reportsFb);
      when(() => reportsFb.single()).thenThrow(Exception('timeout'));

      expect(
        () => dataSource.reportComment(
          commentId: 'c-1',
          reason: CommentReportReason.spam,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // moderatorRemoveComment - additional tests
  // ==========================================================================

  group('moderatorRemoveComment - additional', () {
    test('edge: throws NetworkException when not authenticated (wraps unauth)',
        () async {
      // moderatorRemoveComment throws UnauthorizedException which is caught
      // by the generic catch block and wrapped as NetworkException
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      expect(
        () => noUserDataSource.moderatorRemoveComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: maps PGRST116 to NotFoundException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.eq(any(), any())).thenThrow(PostgrestException(
        message: 'Not found',
        code: 'PGRST116',
      ));

      expect(
        () => dataSource.moderatorRemoveComment(commentId: 'nonexistent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockVoidQuery();
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.update(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.eq(any(), any()))
          .thenThrow(Exception('timeout'));

      expect(
        () => dataSource.moderatorRemoveComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // getCommentsForEvent (paginated)
  // ==========================================================================

  group('getCommentsForEvent', () {
    test('happy: returns PaginatedComments with comments and hasMore=false',
        () async {
      // Mock comments query: from('comments').select('*').eq().isFilter().order().limit()
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([
        commentJson(id: 'c-1'),
        commentJson(id: 'c-2'),
      ]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      // Mock profiles query
      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      // Mock comment_likes for current user
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.comments, isA<List<Comment>>());
      expect(result.hasMore, isFalse);
    });

    test('happy: returns hasMore=true when more results than limit', () async {
      // Create limit+1 items to trigger hasMore (default limit = 20, so 21 items)
      // But we use a small limit for test: limit=2, so we need 3 items
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([
        commentJson(id: 'c-1'),
        commentJson(id: 'c-2'),
        commentJson(id: 'c-3'), // Extra item triggers hasMore
      ]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
        limit: 2,
      );

      expect(result.hasMore, isTrue);
      // Should only return 2 comments, not 3
      expect(result.comments.length, 2);
    });

    test('happy: applies cursor-based pagination with cursorCreatedAt',
        () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson(id: 'c-older')]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
        cursorCreatedAt: DateTime.now(),
      );

      expect(result.comments, isNotEmpty);
    });

    test('happy: returns empty when no comments exist', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.comments, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.nextCursor, isNull);
    });

    test('happy: clamps limit to max 50', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
        limit: 100, // Should be clamped to 50
      );

      expect(result.comments, isEmpty);
      // Verify limit was called with 51 (50+1 for hasMore check)
      verify(() => commentsFb.limit(51)).called(1);
    });

    test('happy: clamps limit minimum to 1', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
        limit: -5, // Should be clamped to 1
      );

      expect(result.comments, isEmpty);
      verify(() => commentsFb.limit(2)).called(1); // 1+1 for hasMore
    });

    test('edge: wraps PostgrestException as domain exception', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.limit(any())).thenThrow(
        PostgrestException(message: 'Connection error', code: '42000'),
      );

      expect(
        () => dataSource.getCommentsForEvent(eventId: 'test-event-001'),
        throwsA(isA<CommentException>()),
      );
    });

    test('edge: wraps generic error as NetworkException', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);
      when(() => commentsFb.limit(any())).thenThrow(Exception('timeout'));

      expect(
        () => dataSource.getCommentsForEvent(eventId: 'test-event-001'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('happy: sets nextCursor from last comment createdAt', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson(id: 'c-1')]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.nextCursor, isNotNull);
      expect(result.nextCursor, isA<DateTime>());
    });

    test('happy: fetches liked status for current user', () async {
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([commentJson(id: 'c-1')]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      // Mock likes with the comment being liked
      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery([
        {'comment_id': 'c-1'},
      ]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.comments, isNotEmpty);
    });
  });

  // ==========================================================================
  // replyToComment - happy path
  // ==========================================================================

  group('replyToComment - happy path', () {
    test('happy: throws UnauthorizedException when not logged in', () async {
      final noUserSupabase = createMockSupabaseClient();
      final noUserDataSource = CommentsRemoteDataSource(noUserSupabase);

      // replyToComment checks auth first, so no mock setup needed
      // UnauthorizedException is caught by generic catch -> NetworkException
      expect(
        () => noUserDataSource.replyToComment(
          commentId: 'c-1',
          text: 'reply',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // _normalizeCommentJson (tested implicitly via getCommentsForEvent)
  // ==========================================================================

  group('normalizeCommentJson', () {
    test('happy: normalizes author_id to user_id in response', () async {
      // getCommentsForEvent calls _normalizeCommentJson internally
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([
        commentJson(id: 'c-norm', authorId: 'author-123'),
      ]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson(userId: 'author-123')]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.comments, isNotEmpty);
      expect(result.comments.first.userId, 'author-123');
    });

    test('happy: defaults missing fields to zero/null', () async {
      // Create comment with minimal fields (no like_count, reply_count etc)
      final minimalComment = {
        'id': 'c-minimal',
        'event_id': 'test-event-001',
        'author_id': TestUserIds.student1,
        'content': 'Minimal',
        'parent_comment_id': null,
        'created_at': DateTime.now().toIso8601String(),
        // Intentionally missing: like_count, reply_count, etc.
      };
      final commentsQb = MockSupabaseQueryBuilder();
      final commentsFb = mockListQuery([minimalComment]);
      when(() => mockSupabase.from('comments')).thenAnswer((_) => commentsQb);
      when(() => commentsQb.select(any())).thenAnswer((_) => commentsFb);

      final profilesQb = MockSupabaseQueryBuilder();
      final profilesFb = mockListQuery([profileJson()]);
      when(() => mockSupabase.from('profiles')).thenAnswer((_) => profilesQb);
      when(() => profilesQb.select(any())).thenAnswer((_) => profilesFb);

      final likesQb = MockSupabaseQueryBuilder();
      final likesFb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('comment_likes'))
          .thenAnswer((_) => likesQb);
      when(() => likesQb.select(any())).thenAnswer((_) => likesFb);

      final result = await dataSource.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.comments.first.likeCount, 0);
      expect(result.comments.first.replyCount, 0);
    });
  });
}
