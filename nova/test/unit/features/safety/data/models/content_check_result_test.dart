import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/safety/data/models/content_check_result.dart';

void main() {
  group('ContentSeverity', () {
    test('fromString parses known values', () {
      expect(ContentSeverity.fromString('warning'), ContentSeverity.warning);
      expect(ContentSeverity.fromString('block'), ContentSeverity.block);
    });

    test('fromString returns warning for unknown values', () {
      expect(ContentSeverity.fromString('unknown'), ContentSeverity.warning);
    });

    test('fromString returns null for null input', () {
      expect(ContentSeverity.fromString(null), isNull);
    });
  });

  group('ContentCheckResult', () {
    // ===================== HAPPY PATH =====================

    test('clean factory creates clean result', () {
      final result = ContentCheckResult.clean();

      expect(result.allowed, true);
      expect(result.blocked, false);
      expect(result.matchedWords, isEmpty);
      expect(result.severity, isNull);
      expect(result.isClean, true);
      expect(result.hasWarnings, false);
    });

    test('fromJson parses blocked content result', () {
      final json = {
        'allowed': false,
        'blocked': true,
        'matched_words': ['badword1', 'badword2'],
        'severity': 'block',
      };

      final result = ContentCheckResult.fromJson(json);

      expect(result.allowed, false);
      expect(result.blocked, true);
      expect(result.matchedWords, ['badword1', 'badword2']);
      expect(result.severity, ContentSeverity.block);
      expect(result.isClean, false);
      expect(result.hasWarnings, false);
    });

    test('warning result has correct computed properties', () {
      const result = ContentCheckResult(
        allowed: true,
        blocked: false,
        matchedWords: ['mild_word'],
        severity: ContentSeverity.warning,
      );

      expect(result.isClean, false);
      expect(result.hasWarnings, true);
    });

    test('equality compares allowed, blocked, and matchedWords', () {
      const a = ContentCheckResult(
        allowed: true,
        blocked: false,
        matchedWords: ['a'],
      );
      const b = ContentCheckResult(
        allowed: true,
        blocked: false,
        matchedWords: ['a'],
      );
      const c = ContentCheckResult(
        allowed: false,
        blocked: true,
        matchedWords: ['a'],
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    // ===================== EDGE CASES =====================

    test('fromJson defaults missing fields', () {
      final result = ContentCheckResult.fromJson({});

      expect(result.allowed, true);
      expect(result.blocked, false);
      expect(result.matchedWords, isEmpty);
      expect(result.severity, isNull);
    });

    test('fromJson handles null matched_words', () {
      final result = ContentCheckResult.fromJson({
        'allowed': false,
        'blocked': true,
        'matched_words': null,
        'severity': 'block',
      });

      expect(result.matchedWords, isEmpty);
    });
  });
}
