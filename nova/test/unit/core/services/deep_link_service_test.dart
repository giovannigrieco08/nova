/// Tests for DeepLinkService
///
/// Tests initialization and disposal behavior.
/// Note: AppLinks is a platform plugin - we test the service's structural behavior.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/services/deep_link_service.dart';

void main() {
  group('DeepLinkService', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    tearDown(() {
      service.dispose();
    });

    // =========================================================================
    // HAPPY PATH
    // =========================================================================

    test('can be instantiated (happy)', () {
      expect(service, isNotNull);
    });

    test('dispose can be called multiple times without error (happy)', () {
      service.dispose();
      service.dispose(); // second call should be safe

      // No exception means success
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    test('dispose before initialize is safe (edge)', () {
      // dispose without ever calling initialize
      final freshService = DeepLinkService();
      freshService.dispose();
      // No exception means success
    });

    test('multiple instances can coexist (edge)', () {
      final service2 = DeepLinkService();

      expect(service, isNot(same(service2)));

      service2.dispose();
    });
  });
}
