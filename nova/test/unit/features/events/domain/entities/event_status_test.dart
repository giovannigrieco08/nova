import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';

void main() {
  group('EventStatus', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should have exactly three values', () {
      expect(EventStatus.values.length, 3);
      expect(EventStatus.values, contains(EventStatus.pending));
      expect(EventStatus.values, contains(EventStatus.approved));
      expect(EventStatus.values, contains(EventStatus.rejected));
    });

    test('label returns correct Italian labels for each status', () {
      expect(EventStatus.pending.label, 'In Revisione');
      expect(EventStatus.approved.label, 'Approvato');
      expect(EventStatus.rejected.label, 'Rifiutato');
    });

    test('colorKey returns correct keys for each status', () {
      expect(EventStatus.pending.colorKey, 'warning');
      expect(EventStatus.approved.colorKey, 'success');
      expect(EventStatus.rejected.colorKey, 'error');
    });

    // =====================================================================
    // Edge Case Tests (E:2)
    // =====================================================================

    test('iconName returns correct icon names for each status', () {
      expect(EventStatus.pending.iconName, 'clock');
      expect(EventStatus.approved.iconName, 'check_circle');
      expect(EventStatus.rejected.iconName, 'cancel');
    });

    test('enum values have correct name strings', () {
      expect(EventStatus.pending.name, 'pending');
      expect(EventStatus.approved.name, 'approved');
      expect(EventStatus.rejected.name, 'rejected');
    });
  });
}
