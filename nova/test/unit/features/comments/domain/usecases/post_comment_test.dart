import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/post_comment.dart';
import 'package:nova/features/comments/domain/exceptions/comments_exceptions.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late PostComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = PostComment(mockRepository);
  });

  group('call', () {
    test('happy: creates comment with valid text', () async {
      final expected = TestComments.topLevel(text: 'Bellissimo evento!');
      when(() => mockRepository.postComment(
            eventId: 'test-event-001',
            text: 'Bellissimo evento!',
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        eventId: 'test-event-001',
        text: 'Bellissimo evento!',
      );

      expect(result.text, 'Bellissimo evento!');
      verify(() => mockRepository.postComment(
            eventId: 'test-event-001',
            text: 'Bellissimo evento!',
          )).called(1);
    });

    test('happy: trims whitespace before posting', () async {
      final expected = TestComments.topLevel(text: 'Testo con spazi');
      when(() => mockRepository.postComment(
            eventId: 'test-event-001',
            text: 'Testo con spazi',
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        eventId: 'test-event-001',
        text: '  Testo con spazi  ',
      );

      expect(result, expected);
      verify(() => mockRepository.postComment(
            eventId: 'test-event-001',
            text: 'Testo con spazi',
          )).called(1);
    });

    test('happy: accepts text at exactly 500 characters', () async {
      final longText = 'a' * 500;
      final expected = TestComments.topLevel(text: longText);
      when(() => mockRepository.postComment(
            eventId: 'test-event-001',
            text: longText,
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        eventId: 'test-event-001',
        text: longText,
      );

      expect(result, expected);
    });

    test('edge: throws ValidationException for empty text', () async {
      expect(
        () => useCase.call(eventId: 'test-event-001', text: ''),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => mockRepository.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          ));
    });

    test('edge: throws ValidationException for whitespace-only text',
        () async {
      expect(
        () => useCase.call(eventId: 'test-event-001', text: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('edge: throws ValidationException for text exceeding 500 chars',
        () async {
      final longText = 'a' * 501;
      expect(
        () => useCase.call(eventId: 'test-event-001', text: longText),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => mockRepository.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          ));
    });
  });
}
