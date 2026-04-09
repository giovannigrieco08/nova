import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/safety/data/models/tos_status.dart';

void main() {
  group('TosStatus', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields', () {
      final status = TosStatus(
        hasAccepted: true,
        acceptedVersion: '1.0.0',
        currentVersion: '1.0.0',
        needsReaccept: false,
        acceptedAt: DateTime(2025, 6, 1),
      );

      expect(status.hasAccepted, true);
      expect(status.acceptedVersion, '1.0.0');
      expect(status.currentVersion, '1.0.0');
      expect(status.needsReaccept, false);
      expect(status.canCreateContent, true);
    });

    test('initial factory creates unaccepted status', () {
      final status = TosStatus.initial();

      expect(status.hasAccepted, false);
      expect(status.acceptedVersion, isNull);
      expect(status.currentVersion, '1.0.0');
      expect(status.needsReaccept, true);
      expect(status.canCreateContent, false);
    });

    test('fromJson parses complete JSON', () {
      final json = {
        'has_accepted': true,
        'accepted_version': '1.0.0',
        'current_version': '2.0.0',
        'needs_reaccept': true,
        'accepted_at': '2025-06-01T10:00:00.000Z',
      };

      final status = TosStatus.fromJson(json);

      expect(status.hasAccepted, true);
      expect(status.acceptedVersion, '1.0.0');
      expect(status.currentVersion, '2.0.0');
      expect(status.needsReaccept, true);
      expect(status.canCreateContent, false);
      expect(status.acceptedAt, isNotNull);
    });

    test('copyWith replaces specified fields', () {
      final initial = TosStatus.initial();
      final accepted = initial.copyWith(
        hasAccepted: true,
        acceptedVersion: '1.0.0',
        needsReaccept: false,
        acceptedAt: DateTime(2025, 6, 1),
      );

      expect(accepted.hasAccepted, true);
      expect(accepted.needsReaccept, false);
      expect(accepted.canCreateContent, true);
    });

    test('equality compares relevant fields', () {
      const a = TosStatus(
        hasAccepted: true,
        acceptedVersion: '1.0.0',
        currentVersion: '1.0.0',
        needsReaccept: false,
      );
      const b = TosStatus(
        hasAccepted: true,
        acceptedVersion: '1.0.0',
        currentVersion: '1.0.0',
        needsReaccept: false,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    // ===================== EDGE CASES =====================

    test('fromJson defaults missing fields', () {
      final status = TosStatus.fromJson({});

      expect(status.hasAccepted, false);
      expect(status.acceptedVersion, isNull);
      expect(status.currentVersion, '1.0.0');
      expect(status.needsReaccept, true);
      expect(status.acceptedAt, isNull);
    });

    test('canCreateContent is false when accepted but needs reaccept', () {
      const status = TosStatus(
        hasAccepted: true,
        acceptedVersion: '1.0.0',
        currentVersion: '2.0.0',
        needsReaccept: true,
      );

      expect(status.canCreateContent, false);
    });
  });

  group('TosAcceptResponse', () {
    test('fromJson parses response correctly', () {
      final json = {
        'success': true,
        'accepted_version': '2.0.0',
        'accepted_at': '2025-06-15T10:00:00.000Z',
      };

      final response = TosAcceptResponse.fromJson(json);

      expect(response.success, true);
      expect(response.acceptedVersion, '2.0.0');
      expect(response.acceptedAt, isA<DateTime>());
    });
  });
}
