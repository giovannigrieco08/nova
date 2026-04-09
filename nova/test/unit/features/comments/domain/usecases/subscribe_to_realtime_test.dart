import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/subscribe_to_realtime.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late SubscribeToRealtime useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = SubscribeToRealtime(mockRepository);
  });

  group('call', () {
    test('happy: returns stream of comments from repository', () async {
      final comments = TestComments.sampleThread(count: 3);
      when(() =>
              mockRepository.subscribeToComments(eventId: 'test-event-001'))
          .thenAnswer((_) => Stream.value(comments));

      final stream = useCase.call(eventId: 'test-event-001');
      final result = await stream.first;

      expect(result.length, 3);
      verify(() =>
              mockRepository.subscribeToComments(eventId: 'test-event-001'))
          .called(1);
    });

    test('happy: emits multiple updates through the stream', () async {
      final firstBatch = TestComments.sampleThread(count: 2);
      final secondBatch = TestComments.sampleThread(count: 4);
      when(() =>
              mockRepository.subscribeToComments(eventId: 'test-event-001'))
          .thenAnswer(
              (_) => Stream.fromIterable([firstBatch, secondBatch]));

      final stream = useCase.call(eventId: 'test-event-001');
      final results = await stream.toList();

      expect(results.length, 2);
      expect(results[0].length, 2);
      expect(results[1].length, 4);
    });

    test('edge: propagates stream errors from repository', () async {
      when(() =>
              mockRepository.subscribeToComments(eventId: 'test-event-001'))
          .thenAnswer((_) => Stream<List<Comment>>.error(
              Exception('WebSocket disconnected')));

      final stream = useCase.call(eventId: 'test-event-001');

      expect(stream, emitsError(isA<Exception>()));
    });

    test('edge: returns empty stream when no comments exist', () async {
      when(() =>
              mockRepository.subscribeToComments(eventId: 'test-event-001'))
          .thenAnswer((_) => Stream.value(<Comment>[]));

      final stream = useCase.call(eventId: 'test-event-001');
      final result = await stream.first;

      expect(result, isEmpty);
    });
  });
}
