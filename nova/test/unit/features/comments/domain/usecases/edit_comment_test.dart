import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/edit_comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late EditComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = EditComment(mockRepository);
  });

  group('call', () {
    test('happy: edits comment with valid text', () async {
      final expected =
          TestComments.topLevel(text: 'Testo modificato').copyWith(
        updatedAt: DateTime.now(),
      );
      when(() => mockRepository.editComment(
            commentId: 'comment-001',
            newText: 'Testo modificato',
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        commentId: 'comment-001',
        newText: 'Testo modificato',
      );

      expect(result.text, 'Testo modificato');
      verify(() => mockRepository.editComment(
            commentId: 'comment-001',
            newText: 'Testo modificato',
          )).called(1);
    });

    test('happy: trims whitespace before editing', () async {
      final expected = TestComments.topLevel(text: 'Trimmed text');
      when(() => mockRepository.editComment(
            commentId: 'comment-001',
            newText: 'Trimmed text',
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        commentId: 'comment-001',
        newText: '  Trimmed text  ',
      );

      expect(result, expected);
      verify(() => mockRepository.editComment(
            commentId: 'comment-001',
            newText: 'Trimmed text',
          )).called(1);
    });

    test('happy: accepts text at exactly 500 characters', () async {
      final longText = 'b' * 500;
      final expected = TestComments.topLevel(text: longText);
      when(() => mockRepository.editComment(
            commentId: 'comment-001',
            newText: longText,
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        commentId: 'comment-001',
        newText: longText,
      );

      expect(result, expected);
    });

    test('happy: propagates repository exceptions (e.g. edit window expired)',
        () async {
      when(() => mockRepository.editComment(
            commentId: 'comment-001',
            newText: 'New text',
          )).thenThrow(Exception('Edit window expired'));

      expect(
        () => useCase.call(commentId: 'comment-001', newText: 'New text'),
        throwsException,
      );
    });

    test('edge: throws EditValidationException for empty text', () async {
      expect(
        () => useCase.call(commentId: 'comment-001', newText: ''),
        throwsA(isA<EditValidationException>()),
      );
      verifyNever(() => mockRepository.editComment(
            commentId: any(named: 'commentId'),
            newText: any(named: 'newText'),
          ));
    });

    test('edge: throws EditValidationException for whitespace-only text',
        () async {
      expect(
        () => useCase.call(commentId: 'comment-001', newText: '   '),
        throwsA(isA<EditValidationException>()),
      );
    });

    test('edge: throws EditValidationException for text exceeding 500 chars',
        () async {
      final longText = 'b' * 501;
      expect(
        () => useCase.call(commentId: 'comment-001', newText: longText),
        throwsA(isA<EditValidationException>()),
      );
    });

    test('edge: repository error does not affect client-side validation',
        () async {
      // Even if repo would succeed, client-side validation rejects first
      expect(
        () => useCase.call(commentId: 'comment-001', newText: ''),
        throwsA(isA<EditValidationException>()),
      );
      verifyNever(() => mockRepository.editComment(
            commentId: any(named: 'commentId'),
            newText: any(named: 'newText'),
          ));
    });
  });

  group('canEdit', () {
    test('returns true for comment created within 5 minutes', () {
      final comment = TestComments.topLevel(
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      expect(useCase.canEdit(comment), true);
    });

    test('returns false for comment created more than 5 minutes ago', () {
      final comment = TestComments.topLevel(
        createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
      );
      expect(useCase.canEdit(comment), false);
    });
  });

  group('remainingEditSeconds', () {
    test('returns remaining seconds within edit window', () {
      final comment = TestComments.topLevel(
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      final remaining = useCase.remainingEditSeconds(comment);
      // Should be roughly 120 seconds (2 minutes remaining)
      expect(remaining, greaterThan(100));
      expect(remaining, lessThanOrEqualTo(120));
    });

    test('returns 0 when edit window has expired', () {
      final comment = TestComments.topLevel(
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(useCase.remainingEditSeconds(comment), 0);
    });
  });
}
