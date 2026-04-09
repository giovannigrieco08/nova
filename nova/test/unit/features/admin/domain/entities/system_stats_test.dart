import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';

void main() {
  group('SystemStats', () {
    // ===================== HAPPY PATH =====================

    test('creates with default values', () {
      const stats = SystemStats();

      expect(stats.totalEvents, 0);
      expect(stats.pendingEvents, 0);
      expect(stats.approvedEvents, 0);
      expect(stats.rejectedEvents, 0);
      expect(stats.totalModerators, 0);
      expect(stats.activeModerators, 0);
      expect(stats.avgReviewTimeHours, 0.0);
      expect(stats.eventsOlderThan24h, 0);
    });

    test('creates with explicit values', () {
      const stats = SystemStats(
        totalEvents: 100,
        pendingEvents: 5,
        approvedEvents: 80,
        rejectedEvents: 15,
        totalModerators: 3,
        activeModerators: 2,
        avgReviewTimeHours: 4.5,
        eventsOlderThan24h: 2,
      );

      expect(stats.totalEvents, 100);
      expect(stats.approvedEvents, 80);
      expect(stats.avgReviewTimeHours, 4.5);
    });
  });

  group('SystemStatsX extensions', () {
    // ===================== HAPPY PATH =====================

    test('approvalRatePercent calculates correctly', () {
      const stats = SystemStats(
        approvedEvents: 80,
        rejectedEvents: 20,
      );

      expect(stats.approvalRatePercent, 80.0);
    });

    test('hasBacklogCrisis returns true when more than 10 events older than 24h',
        () {
      const crisis = SystemStats(eventsOlderThan24h: 15);
      expect(crisis.hasBacklogCrisis, true);

      const ok = SystemStats(eventsOlderThan24h: 5);
      expect(ok.hasBacklogCrisis, false);
    });

    // ===================== EDGE CASES =====================

    test('approvalRatePercent returns 0.0 when no reviews', () {
      const stats = SystemStats();
      expect(stats.approvalRatePercent, 0.0);
    });
  });
}
