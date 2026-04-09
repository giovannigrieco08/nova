import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/safety/domain/services/content_filter_service.dart';
import 'package:nova/features/safety/data/repositories/content_filter_repository.dart';
import 'package:nova/features/safety/data/models/content_check_result.dart';

class MockContentFilterRepository extends Mock
    implements ContentFilterRepository {}

void main() {
  late ContentFilterService service;
  late MockContentFilterRepository mockRepository;

  setUp(() {
    mockRepository = MockContentFilterRepository();
    service = ContentFilterService(repository: mockRepository);
  });

  group('ContentFilterService', () {
    // ===== HAPPY PATH TESTS =====

    test('checkContent returns clean result for allowed text', () async {
      when(() => mockRepository.checkContent(any()))
          .thenAnswer((_) async => ContentCheckResult.clean());

      final result = await service.checkContent('Ciao a tutti!');

      expect(result.isClean, isTrue);
      expect(result.blocked, isFalse);
      verify(() => mockRepository.checkContent('Ciao a tutti!')).called(1);
    });

    test('validateContent completes without error for clean content', () async {
      when(() => mockRepository.checkContent(any()))
          .thenAnswer((_) async => ContentCheckResult.clean());

      await expectLater(
        service.validateContent('Testo pulito'),
        completes,
      );
    });

    test('isContentClean returns true for clean text', () async {
      when(() => mockRepository.checkContent(any()))
          .thenAnswer((_) async => ContentCheckResult.clean());

      final result = await service.isContentClean('Bel contenuto');

      expect(result, isTrue);
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('checkContent returns clean result for very short text (< 3 chars)',
        () async {
      final result = await service.checkContent('ab');

      expect(result.isClean, isTrue);
      expect(result.blocked, isFalse);
      verifyNever(() => mockRepository.checkContent(any()));
    });

    test('validateContent throws ContentBlockedException for blocked content',
        () async {
      when(() => mockRepository.checkContent(any())).thenAnswer(
        (_) async => const ContentCheckResult(
          allowed: false,
          blocked: true,
          matchedWords: ['parolaccia'],
          severity: ContentSeverity.block,
        ),
      );

      expect(
        () => service.validateContent('Contiene parolaccia vietata'),
        throwsA(isA<ContentBlockedException>()),
      );
    });
  });
}
