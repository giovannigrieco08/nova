import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/get_comments_for_event.dart';
import 'package:nova/features/comments/domain/repositories/comments_repository_interface.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late GetCommentsForEvent useCase;
  late MockCommentsRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(CommentSortOrder.recent);
  });

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = GetCommentsForEvent(mockRepository);
  });

  group('call', () {
    test('happy: returns paginated comments for event with default params',
        () async {
      final comments = TestComments.sampleThread(count: 3);
      final expected = PaginatedComments(
        comments: comments,
        hasMore: true,
        nextCursor: comments.last.createdAt,
      );
      when(() => mockRepository.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: CommentSortOrder.recent,
            limit: 20,
            cursorCreatedAt: null,
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(eventId: 'test-event-001');

      expect(result.comments.length, 3);
      expect(result.hasMore, true);
      verify(() => mockRepository.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: CommentSortOrder.recent,
            limit: 20,
            cursorCreatedAt: null,
          )).called(1);
    });

    test('happy: returns comments sorted by popular', () async {
      final comments = TestComments.sampleThread(count: 2);
      final expected = PaginatedComments(
        comments: comments,
        hasMore: false,
      );
      when(() => mockRepository.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: CommentSortOrder.popular,
            limit: 10,
            cursorCreatedAt: null,
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        eventId: 'test-event-001',
        sortOrder: CommentSortOrder.popular,
        limit: 10,
      );

      expect(result.comments.length, 2);
      expect(result.hasMore, false);
    });

    test('happy: returns empty list when no comments exist', () async {
      final expected = PaginatedComments(
        comments: [],
        hasMore: false,
      );
      when(() => mockRepository.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: CommentSortOrder.recent,
            limit: 20,
            cursorCreatedAt: null,
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(eventId: 'test-event-001');

      expect(result.comments, isEmpty);
      expect(result.hasMore, false);
    });

    test('edge: throws when repository throws network error', () async {
      when(() => mockRepository.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: CommentSortOrder.recent,
            limit: 20,
            cursorCreatedAt: null,
          )).thenThrow(Exception('Network error'));

      expect(
        () => useCase.call(eventId: 'test-event-001'),
        throwsException,
      );
    });

    test('edge: passes cursor through for pagination', () async {
      final cursor = DateTime(2025, 1, 15, 10, 30);
      final expected = PaginatedComments(
        comments: [],
        hasMore: false,
      );
      when(() => mockRepository.getCommentsForEvent(
            eventId: any(named: 'eventId'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenAnswer((_) async => expected);

      await useCase.call(
        eventId: 'test-event-001',
        cursorCreatedAt: cursor,
      );

      verify(() => mockRepository.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: CommentSortOrder.recent,
            limit: 20,
            cursorCreatedAt: cursor,
          )).called(1);
    });
  });
}
