import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/search/data/datasources/search_local_datasource.dart';
import 'package:nova/features/search/data/datasources/search_remote_datasource.dart';
import 'package:nova/features/search/data/models/search_results_cache.dart';
import 'package:nova/features/search/data/repositories/search_repository.dart';
import 'package:nova/features/search/domain/entities/search_results.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockSearchRemoteDataSource extends Mock
    implements SearchRemoteDataSource {}

class MockSearchLocalDataSource extends Mock implements SearchLocalDataSource {}

class MockConnectivity extends Mock implements Connectivity {}

// ============================================================================
// HELPERS
// ============================================================================

SearchResults _testResults({
  String query = 'test',
  bool fromCache = false,
}) {
  return SearchResults(
    events: [
      EventSearchResult(
        id: 'event-1',
        title: 'Test Event',
        description: 'Desc',
        location: 'Aula Magna',
        creatorId: 'user-001',
        rank: 1.0,
      ),
    ],
    profiles: [
      ProfileSearchResult(
        id: 'user-001',
        fullName: 'Mario Rossi',
        bio: 'Ciao',
        className: '4A',
        rank: 1.0,
      ),
    ],
    query: query,
    timestamp: DateTime(2025, 6, 1),
    isFromCache: fromCache,
  );
}

SearchResultsCache _testCache({String query = 'test'}) {
  return SearchResultsCache(
    query: query,
    timestamp: DateTime.now(),
    events: [
      CachedEventResult(
        id: 'event-1',
        title: 'Test Event',
        description: 'Desc',
        location: 'Aula Magna',
        creatorId: 'user-001',
      ),
    ],
    profiles: [
      CachedProfileResult(
        id: 'user-001',
        fullName: 'Mario Rossi',
        bio: 'Ciao',
        className: '4A',
      ),
    ],
  );
}

void main() {
  late SearchRepository repository;
  late MockSearchRemoteDataSource mockRemote;
  late MockSearchLocalDataSource mockLocal;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockRemote = MockSearchRemoteDataSource();
    mockLocal = MockSearchLocalDataSource();
    mockConnectivity = MockConnectivity();
    repository = SearchRepository(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
      connectivity: mockConnectivity,
    );
  });

  setUpAll(() {
    registerFallbackValue(SearchResultsCache(
      query: '',
      timestamp: DateTime(2025),
      events: [],
      profiles: [],
    ));
    registerFallbackValue(Duration.zero);
    registerFallbackValue(ConnectivityResult.none);
    registerFallbackValue('');
  });

  // ==========================================================================
  // search - Happy paths
  // ==========================================================================

  group('search', () {
    test('returns remote results when online and no valid cache', () async {
      when(() => mockLocal.isCacheValid(any(), any())).thenReturn(false);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.searchAll('test'))
          .thenAnswer((_) async => _testResults());
      when(() => mockLocal.cacheResults(any())).thenAnswer((_) async {});

      final result = await repository.search('test');

      expect(result.events.length, 1);
      expect(result.profiles.length, 1);
      verify(() => mockRemote.searchAll('test')).called(1);
    });

    test('returns cached results when cache is valid', () async {
      final cache = _testCache();
      when(() => mockLocal.isCacheValid('test', any())).thenReturn(true);
      when(() => mockLocal.getCachedResults('test')).thenReturn(cache);

      final result = await repository.search('test');

      expect(result.isFromCache, true);
      expect(result.events.length, 1);
      verifyNever(() => mockRemote.searchAll(any()));
    });

    test('returns empty results for short queries', () async {
      final result = await repository.search('a');

      expect(result.totalCount, 0);
      verifyNever(() => mockRemote.searchAll(any()));
    });

    test('trims whitespace from query', () async {
      when(() => mockLocal.isCacheValid(any(), any())).thenReturn(false);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.searchAll('test'))
          .thenAnswer((_) async => _testResults());
      when(() => mockLocal.cacheResults(any())).thenAnswer((_) async {});

      await repository.search('  test  ');

      verify(() => mockRemote.searchAll('test')).called(1);
    });

    // Edge: offline falls back to offline search
    test('falls back to offline search when offline', () async {
      when(() => mockLocal.isCacheValid(any(), any())).thenReturn(false);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      when(() => mockLocal.getCachedResults('test')).thenReturn(null);
      when(() => mockLocal.getAllCachedResults()).thenReturn([]);

      final result = await repository.search('test');

      expect(result.isFromCache, true);
      verifyNever(() => mockRemote.searchAll(any()));
    });

    // Edge: cache valid but getCachedResults returns null
    test('fetches remote when cache claims valid but returns null', () async {
      when(() => mockLocal.isCacheValid('test', any())).thenReturn(true);
      when(() => mockLocal.getCachedResults('test')).thenReturn(null);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      when(() => mockRemote.searchAll('test'))
          .thenAnswer((_) async => _testResults());
      when(() => mockLocal.cacheResults(any())).thenAnswer((_) async {});

      final result = await repository.search('test');

      expect(result.isFromCache, false);
    });
  });

  // ==========================================================================
  // searchOffline - Race condition: cached data partially matching
  // ==========================================================================

  group('searchOffline', () {
    test('searches through all cached data for matches', () async {
      final cache = _testCache(query: 'previous');
      // Direct cache miss for 'test', then fallback to scanning all cached results
      when(() => mockLocal.getCachedResults('test')).thenReturn(null);
      when(() => mockLocal.getAllCachedResults()).thenReturn([cache]);

      final result = await repository.searchOffline('test');

      // 'Test Event' contains 'test' (case-insensitive)
      expect(result.events.length, 1);
      expect(result.isFromCache, true);
    });
  });

  // ==========================================================================
  // Search history
  // ==========================================================================

  group('search history', () {
    test('getSearchHistory delegates to local', () {
      when(() => mockLocal.getSearchHistory())
          .thenReturn(['test1', 'test2']);

      final result = repository.getSearchHistory();

      expect(result, ['test1', 'test2']);
    });

    test('addToHistory delegates to local', () async {
      when(() => mockLocal.addToHistory('query'))
          .thenAnswer((_) async {});

      await repository.addToHistory('query');

      verify(() => mockLocal.addToHistory('query')).called(1);
    });

    test('clearHistory delegates to local', () async {
      when(() => mockLocal.clearHistory()).thenAnswer((_) async {});

      await repository.clearHistory();

      verify(() => mockLocal.clearHistory()).called(1);
    });
  });

  // ==========================================================================
  // Cache management
  // ==========================================================================

  group('cache management', () {
    test('invalidateCache clears all cache', () async {
      when(() => mockLocal.clearCache()).thenAnswer((_) async {});

      await repository.invalidateCache();

      verify(() => mockLocal.clearCache()).called(1);
    });
  });
}
