/// Tests for DeepLinkHandler
///
/// Tests deep link parsing logic for event and profile URIs.
/// AppLinks is a platform plugin - we test the parse() method directly.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/utils/deep_link_handler.dart';

void main() {
  group('DeepLinkHandler', () {
    late DeepLinkHandler handler;

    setUp(() {
      handler = DeepLinkHandler();
    });

    // =========================================================================
    // HAPPY PATH - Event parsing
    // =========================================================================

    group('parse event links', () {
      test('valid event deep link returns event info (happy)', () {
        final uri = Uri.parse(
            'nova://events/123e4567-e89b-12d3-a456-426614174000');

        final result = handler.parse(uri);

        expect(result, isNotNull);
        expect(result!.type, equals(DeepLinkType.event));
        expect(result.eventId, equals('123e4567-e89b-12d3-a456-426614174000'));
      });

      test('valid profile deep link returns profile info (happy)', () {
        final uri = Uri.parse(
            'nova://profile/123e4567-e89b-12d3-a456-426614174000');

        final result = handler.parse(uri);

        expect(result, isNotNull);
        expect(result!.type, equals(DeepLinkType.profile));
        expect(result.userId, equals('123e4567-e89b-12d3-a456-426614174000'));
      });

      test('event link toString contains event ID (happy)', () {
        final uri = Uri.parse(
            'nova://events/123e4567-e89b-12d3-a456-426614174000');
        final result = handler.parse(uri);

        expect(result!.toString(), contains('event'));
        expect(result.toString(), contains('123e4567'));
      });
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    group('parse edge cases', () {
      test('wrong scheme returns null (edge)', () {
        final uri = Uri.parse(
            'https://events/123e4567-e89b-12d3-a456-426614174000');

        expect(handler.parse(uri), isNull);
      });

      test('empty path returns null (edge)', () {
        final uri = Uri.parse('nova://');

        // Uri.parse('nova://') has host="" and empty pathSegments
        expect(handler.parse(uri), isNull);
      });

      test('unknown path type returns null (edge)', () {
        final uri = Uri.parse(
            'nova://settings/123e4567-e89b-12d3-a456-426614174000');

        expect(handler.parse(uri), isNull);
      });

      test('event link without ID returns null (edge)', () {
        final uri = Uri.parse('nova://events');

        // pathSegments will be ['events'] with length < 2
        expect(handler.parse(uri), isNull);
      });

      test('invalid UUID format returns null (edge)', () {
        final uri = Uri.parse('nova://events/not-a-valid-uuid');

        expect(handler.parse(uri), isNull);
      });

      test('profile link without ID returns null (edge)', () {
        final uri = Uri.parse('nova://profile');

        expect(handler.parse(uri), isNull);
      });
    });

    // =========================================================================
    // RACE CONDITION - concurrent parse
    // =========================================================================

    group('concurrent usage', () {
      test('parse is stateless and reentrant (race)', () {
        final uri1 = Uri.parse(
            'nova://events/11111111-1111-1111-1111-111111111111');
        final uri2 = Uri.parse(
            'nova://profile/22222222-2222-2222-2222-222222222222');

        final result1 = handler.parse(uri1);
        final result2 = handler.parse(uri2);

        expect(result1!.type, equals(DeepLinkType.event));
        expect(result1.eventId, contains('11111111'));
        expect(result2!.type, equals(DeepLinkType.profile));
        expect(result2.userId, contains('22222222'));
      });
    });
  });

  // ===========================================================================
  // DeepLinkInfo
  // ===========================================================================

  group('DeepLinkInfo', () {
    test('event toString format (happy)', () {
      final info = DeepLinkInfo(
        type: DeepLinkType.event,
        eventId: 'test-id',
      );
      expect(info.toString(), equals('DeepLinkInfo(event: test-id)'));
    });

    test('profile toString format (happy)', () {
      final info = DeepLinkInfo(
        type: DeepLinkType.profile,
        userId: 'user-id',
      );
      expect(info.toString(), equals('DeepLinkInfo(profile: user-id)'));
    });
  });
}
