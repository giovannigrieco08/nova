import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/search/domain/entities/search_results.dart';

void main() {
  group('EventSearchResult', () {
    // ===================== HAPPY PATH =====================

    test('creates from valid JSON', () {
      final json = {
        'id': 'evt-1',
        'title': 'Test Event',
        'description': 'A description',
        'location': 'Aula Magna',
        'event_date': '2025-06-15T10:00:00.000Z',
        'image_url': 'https://example.com/img.jpg',
        'creator_id': 'user-001',
        'rank': 0.95,
      };

      final result = EventSearchResult.fromJson(json);

      expect(result.id, 'evt-1');
      expect(result.title, 'Test Event');
      expect(result.description, 'A description');
      expect(result.location, 'Aula Magna');
      expect(result.eventDate, isNotNull);
      expect(result.imageUrl, 'https://example.com/img.jpg');
      expect(result.creatorId, 'user-001');
      expect(result.rank, 0.95);
    });

    test('equality is based on id', () {
      const a = EventSearchResult(
          id: 'e1', title: 'A', creatorId: 'c1', rank: 1.0);
      const b = EventSearchResult(
          id: 'e1', title: 'B', creatorId: 'c2', rank: 0.5);
      const c = EventSearchResult(
          id: 'e2', title: 'A', creatorId: 'c1', rank: 1.0);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    // ===================== EDGE CASES =====================

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'evt-1',
        'title': 'Event',
        'description': null,
        'location': null,
        'event_date': null,
        'image_url': null,
        'creator_id': 'user-001',
        'rank': 0,
      };

      final result = EventSearchResult.fromJson(json);

      expect(result.description, isNull);
      expect(result.location, isNull);
      expect(result.eventDate, isNull);
      expect(result.imageUrl, isNull);
      expect(result.rank, 0.0);
    });
  });

  group('ProfileSearchResult', () {
    test('creates from valid JSON', () {
      final json = {
        'user_id': 'user-001',
        'full_name': 'Mario Rossi',
        'bio': 'Ciao!',
        'class_name': '4A',
        'avatar_url': 'https://example.com/avatar.jpg',
        'rank': 0.8,
      };

      final result = ProfileSearchResult.fromJson(json);

      expect(result.id, 'user-001');
      expect(result.fullName, 'Mario Rossi');
      expect(result.bio, 'Ciao!');
      expect(result.className, '4A');
      expect(result.rank, 0.8);
    });

    test('equality is based on id', () {
      const a =
          ProfileSearchResult(id: 'u1', fullName: 'A', rank: 1.0);
      const b =
          ProfileSearchResult(id: 'u1', fullName: 'B', rank: 0.5);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SearchResults', () {
    // ===================== HAPPY PATH =====================

    test('empty factory creates empty results', () {
      final results = SearchResults.empty();

      expect(results.events, isEmpty);
      expect(results.profiles, isEmpty);
      expect(results.query, '');
      expect(results.isFromCache, false);
      expect(results.totalCount, 0);
      expect(results.hasResults, false);
    });

    test('totalCount and hasResults reflect actual content', () {
      final results = SearchResults(
        events: const [
          EventSearchResult(
              id: 'e1', title: 'E', creatorId: 'c1', rank: 1.0),
        ],
        profiles: const [
          ProfileSearchResult(id: 'u1', fullName: 'P', rank: 1.0),
          ProfileSearchResult(id: 'u2', fullName: 'Q', rank: 0.5),
        ],
        query: 'test',
        timestamp: DateTime(2025, 6, 1),
      );

      expect(results.totalCount, 3);
      expect(results.hasResults, true);
    });

    test('isStale returns true when older than TTL', () {
      final old = SearchResults(
        events: const [],
        profiles: const [],
        query: 'q',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      expect(old.isStale(const Duration(minutes: 5)), true);
      expect(old.isStale(const Duration(minutes: 15)), false);
    });

    // ===================== EDGE CASES =====================

    test('copyWithCacheFlag preserves data and updates flag', () {
      final original = SearchResults(
        events: const [
          EventSearchResult(
              id: 'e1', title: 'E', creatorId: 'c1', rank: 1.0),
        ],
        profiles: const [],
        query: 'test',
        timestamp: DateTime(2025, 6, 1),
        isFromCache: false,
      );

      final cached = original.copyWithCacheFlag(true);

      expect(cached.isFromCache, true);
      expect(cached.events.length, 1);
      expect(cached.query, 'test');
    });

    test('isStale returns false for fresh results', () {
      final fresh = SearchResults(
        events: const [],
        profiles: const [],
        query: 'q',
        timestamp: DateTime.now(),
      );

      expect(fresh.isStale(const Duration(minutes: 5)), false);
    });

    test('empty results have zero epoch timestamp', () {
      final empty = SearchResults.empty();
      expect(empty.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });
}
