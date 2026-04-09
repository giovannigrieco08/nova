import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/search/data/datasources/search_remote_datasource.dart';
import 'package:nova/features/search/domain/entities/search_results.dart';

import '../../../../../mocks/mock_supabase.dart';

void main() {
  late SearchRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = createMockSupabaseClient(userId: 'test-student-001');
    dataSource = SearchRemoteDataSource(mockSupabase);
  });

  // ==========================================================================
  // Helper JSON
  // ==========================================================================

  Map<String, dynamic> eventResultJson({String id = 'event-1'}) {
    return {
      'id': id,
      'title': 'Festa di Fine Anno',
      'description': 'Grande festa',
      'location': 'Aula Magna',
      'event_date': '2026-06-15T18:00:00.000Z',
      'image_url': null,
      'creator_id': 'user-1',
      'rank': 0.85,
    };
  }

  Map<String, dynamic> profileResultJson({String userId = 'user-1'}) {
    return {
      'user_id': userId,
      'full_name': 'Mario Rossi',
      'bio': 'Studente 4A',
      'class_name': '4A',
      'avatar_url': null,
      'rank': 0.75,
    };
  }

  // ==========================================================================
  // searchEvents
  // ==========================================================================

  group('searchEvents', () {
    test('happy: returns list of EventSearchResult from RPC', () async {
      final rpcFb = mockListQuery([eventResultJson(), eventResultJson(id: 'event-2')]);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.searchEvents('festa');

      expect(result.length, 2);
      expect(result.first, isA<EventSearchResult>());
      expect(result.first.title, 'Festa di Fine Anno');
    });

    test('edge: returns empty list for short query (< 2 chars)', () async {
      final result = await dataSource.searchEvents('f');

      expect(result, isEmpty);
      verifyNever(() => mockSupabase.rpc(any(), params: any(named: 'params')));
    });

    test('edge: trims whitespace before length check', () async {
      final result = await dataSource.searchEvents('  a  ');

      expect(result, isEmpty);
      verifyNever(() => mockSupabase.rpc(any(), params: any(named: 'params')));
    });
  });

  // ==========================================================================
  // searchProfiles
  // ==========================================================================

  group('searchProfiles', () {
    test('happy: returns list of ProfileSearchResult from RPC', () async {
      final rpcFb = mockListQuery([profileResultJson()]);
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) => rpcFb);

      final result = await dataSource.searchProfiles('mario');

      expect(result.length, 1);
      expect(result.first, isA<ProfileSearchResult>());
      expect(result.first.fullName, 'Mario Rossi');
    });

    test('edge: returns empty list for short query', () async {
      final result = await dataSource.searchProfiles('m');

      expect(result, isEmpty);
    });
  });

  // ==========================================================================
  // searchAll
  // ==========================================================================

  group('searchAll', () {
    test('happy: returns combined SearchResults with events and profiles',
        () async {
      final rpcFb1 = mockListQuery([eventResultJson()]);
      final rpcFb2 = mockListQuery([profileResultJson()]);
      int rpcCallCount = 0;
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) {
        rpcCallCount++;
        return rpcCallCount == 1 ? rpcFb1 : rpcFb2;
      });

      final result = await dataSource.searchAll('mario');

      expect(result, isA<SearchResults>());
      expect(result.events.length, 1);
      expect(result.profiles.length, 1);
      expect(result.query, 'mario');
      expect(result.isFromCache, isFalse);
    });

    test('edge: returns empty SearchResults for short query', () async {
      final result = await dataSource.searchAll('m');

      expect(result.events, isEmpty);
      expect(result.profiles, isEmpty);
      expect(result.hasResults, isFalse);
    });
  });
}
