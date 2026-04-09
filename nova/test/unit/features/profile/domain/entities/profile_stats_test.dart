import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/profile/domain/entities/profile_stats.dart';

void main() {
  group('ProfileStats', () {
    // ===================== HAPPY PATH =====================

    test('creates with required fields and computes totalActivity', () {
      const stats = ProfileStats(
        eventsCreatedCount: 5,
        participationsCount: 10,
      );

      expect(stats.eventsCreatedCount, 5);
      expect(stats.participationsCount, 10);
      expect(stats.totalActivity, 15);
    });

    test('empty factory creates zero stats', () {
      final stats = ProfileStats.empty();

      expect(stats.eventsCreatedCount, 0);
      expect(stats.participationsCount, 0);
      expect(stats.totalActivity, 0);
    });

    test('fromJson and toJson roundtrip correctly', () {
      final json = {
        'events_created_count': 3,
        'participations_count': 7,
      };

      final stats = ProfileStats.fromJson(json);
      expect(stats.eventsCreatedCount, 3);
      expect(stats.participationsCount, 7);

      final output = stats.toJson();
      expect(output['events_created_count'], 3);
      expect(output['participations_count'], 7);
    });

    test('copyWith replaces specified fields', () {
      const original = ProfileStats(
        eventsCreatedCount: 1,
        participationsCount: 2,
      );

      final modified = original.copyWith(eventsCreatedCount: 10);
      expect(modified.eventsCreatedCount, 10);
      expect(modified.participationsCount, 2);
    });

    test('equality and hashCode', () {
      const a = ProfileStats(eventsCreatedCount: 1, participationsCount: 2);
      const b = ProfileStats(eventsCreatedCount: 1, participationsCount: 2);
      const c = ProfileStats(eventsCreatedCount: 3, participationsCount: 2);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    // ===================== EDGE CASES =====================

    test('fromJson defaults missing fields to 0', () {
      final stats = ProfileStats.fromJson({});

      expect(stats.eventsCreatedCount, 0);
      expect(stats.participationsCount, 0);
    });

    test('fromJson handles null values as 0', () {
      final stats = ProfileStats.fromJson({
        'events_created_count': null,
        'participations_count': null,
      });

      expect(stats.eventsCreatedCount, 0);
      expect(stats.participationsCount, 0);
    });
  });
}
