/// Mock Supabase client for testing.
///
/// Provides mocked versions of Supabase client and related classes
/// for unit and widget testing without actual network calls.
library;

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mock SupabaseClient
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Mock GoTrueClient (Auth)
class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Mock User
class MockUser extends Mock implements User {}

/// Mock SupabaseQueryBuilder
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Mock PostgrestFilterBuilder (generic)
class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {}

/// Convenience: the most common filter builder type from .select()
typedef MockPostgrestListFilterBuilder
    = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>;

/// Convenience: filter builder for .single() / .maybeSingle()
typedef MockPostgrestMapFilterBuilder
    = MockPostgrestFilterBuilder<Map<String, dynamic>>;

/// Mock PostgrestTransformBuilder (generic)
class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}

/// Convenience: the most common transform builder type
typedef MockPostgrestListTransformBuilder
    = MockPostgrestTransformBuilder<List<Map<String, dynamic>>>;

/// Convenience: transform builder for .single()
typedef MockPostgrestMapTransformBuilder
    = MockPostgrestTransformBuilder<Map<String, dynamic>>;

/// Mock SupabaseStorageClient
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

/// Mock StorageFileApi
class MockStorageFileApi extends Mock implements StorageFileApi {}

/// Mock RealtimeChannel
class MockRealtimeChannel extends Mock implements RealtimeChannel {}

/// Create a fully configured mock Supabase client
///
/// Returns a [MockSupabaseClient] with auth mocked to return a test user.
MockSupabaseClient createMockSupabaseClient({
  String? userId,
  String? userEmail,
}) {
  final mockClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();

  when(() => mockClient.auth).thenReturn(mockAuth);

  if (userId != null) {
    final mockUser = MockUser();
    when(() => mockUser.id).thenReturn(userId);
    when(() => mockUser.email).thenReturn(userEmail ?? 'test@galileimoro.edu.it');
    when(() => mockAuth.currentUser).thenReturn(mockUser);
  } else {
    when(() => mockAuth.currentUser).thenReturn(null);
  }

  return mockClient;
}

// ==========================================================================
// Supabase query chain helpers
// ==========================================================================

bool _fallbacksRegistered = false;

/// Register fallback values needed by the mock helpers.
/// Call this in setUpAll() or before using mockListQuery/mockSingleQuery.
void ensureMockFallbacks() {
  if (_fallbacksRegistered) return;
  _fallbacksRegistered = true;
  registerFallbackValue((List<Map<String, dynamic>> _) => null);
  registerFallbackValue((dynamic _) => null);
  registerFallbackValue(<Map<String, dynamic>>[]);
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue('');
  registerFallbackValue(0);
  registerFallbackValue(Duration.zero);
}

/// Helper: creates a mock transform builder that resolves to [data] when awaited.
MockPostgrestTransformBuilder<T> mockTransformBuilder<T>(T data) {
  final tb = MockPostgrestTransformBuilder<T>();
  // When `await tb` is called, Dart invokes `tb.then(callback)`.
  // We must invoke the callback with our data so the await completes.
  // Use Function (not a typed cast) to avoid subtype errors.
  when(() => tb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(data));
  });
  return tb;
}

/// Internal: sets up standard filter method stubs on a list-typed
/// [MockPostgrestFilterBuilder] so that chained calls (eq, neq, order, etc.)
/// all return the builder itself, and awaiting resolves to [data].
///
/// Uses `thenAnswer` instead of `thenReturn` because the mock implements
/// `Future` (via PostgrestBuilder), and mocktail forbids `thenReturn` for
/// Future-implementing objects.
void _stubListFilterBuilder(
  MockPostgrestFilterBuilder<List<Map<String, dynamic>>> fb,
  List<Map<String, dynamic>> data,
) {
  ensureMockFallbacks();
  // All filter methods return self (same generic T)
  when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
  when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
  when(() => fb.gt(any(), any())).thenAnswer((_) => fb);
  when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
  when(() => fb.lt(any(), any())).thenAnswer((_) => fb);
  when(() => fb.lte(any(), any())).thenAnswer((_) => fb);
  when(() => fb.or(any())).thenAnswer((_) => fb);
  when(() => fb.not(any(), any(), any())).thenAnswer((_) => fb);
  when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);
  when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
  when(() => fb.contains(any(), any())).thenAnswer((_) => fb);

  // Transform methods that preserve the list type return self
  when(() => fb.order(any(), ascending: any(named: 'ascending')))
      .thenAnswer((_) => fb);
  when(() => fb.limit(any())).thenAnswer((_) => fb);
  when(() => fb.range(any(), any())).thenAnswer((_) => fb);

  // .select() returns self (PostgrestFilterBuilder extends PostgrestTransformBuilder)
  when(() => fb.select(any())).thenAnswer((_) => fb);
  when(() => fb.select()).thenAnswer((_) => fb);

  // When `await fb` is called, invoke the continuation callback with data.
  when(() => fb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(data));
  });
}

/// Helper: creates a filter builder that resolves to a list of maps.
/// This is the most common case for `.from('table').select()` queries.
///
/// Also stubs `.single()` and `.maybeSingle()` with properly typed transform
/// builders so that chains ending in those calls compile and resolve correctly.
///
/// Usage:
/// ```dart
/// final fb = mockListQuery([{'id': '1'}]);
/// when(() => mockQb.select(any())).thenReturn(fb);
/// // fb.eq(...).order(...) all return fb
/// // await fb resolves to [{'id': '1'}]
/// // await fb.maybeSingle() resolves to {'id': '1'}
/// ```
MockPostgrestFilterBuilder<List<Map<String, dynamic>>> mockListQuery(
    List<Map<String, dynamic>> data) {
  final fb = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
  _stubListFilterBuilder(fb, data);

  // .maybeSingle() returns PostgrestTransformBuilder<Map<String, dynamic>?>
  final maybeSingleTb = mockTransformBuilder<Map<String, dynamic>?>(
    data.isNotEmpty ? data.first : null,
  );
  when(() => fb.maybeSingle()).thenAnswer((_) => maybeSingleTb);

  // .single() returns PostgrestTransformBuilder<Map<String, dynamic>>
  if (data.isNotEmpty) {
    final singleTb = mockTransformBuilder<Map<String, dynamic>>(data.first);
    when(() => fb.single()).thenAnswer((_) => singleTb);
  }

  return fb;
}

/// Helper: creates a filter builder for insert/upsert -> select -> single chains.
///
/// Uses a list-typed filter builder (matching the real return type of
/// `.insert()` / `.update()` / `.delete()`) but stubs `.single()` and
/// `.maybeSingle()` to resolve to the provided single map [data].
///
/// Usage:
/// ```dart
/// final fb = mockSingleQuery({'id': '1', 'name': 'test'});
/// when(() => mockQb.insert(any())).thenReturn(fb);
/// // await fb.select(...).single() resolves to {'id': '1', 'name': 'test'}
/// ```
MockPostgrestFilterBuilder<List<Map<String, dynamic>>> mockSingleQuery(
    Map<String, dynamic> data) {
  final fb = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
  _stubListFilterBuilder(fb, [data]);

  // .single() returns PostgrestTransformBuilder<Map<String, dynamic>>
  final singleTb = mockTransformBuilder<Map<String, dynamic>>(data);
  when(() => fb.single()).thenAnswer((_) => singleTb);

  // .maybeSingle() returns PostgrestTransformBuilder<Map<String, dynamic>?>
  final maybeSingleTb = mockTransformBuilder<Map<String, dynamic>?>(data);
  when(() => fb.maybeSingle()).thenAnswer((_) => maybeSingleTb);

  return fb;
}

/// Helper: creates a filter builder for delete/update that resolves to empty list.
MockPostgrestFilterBuilder<List<Map<String, dynamic>>> mockVoidQuery() {
  final fb = MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
  _stubListFilterBuilder(fb, <Map<String, dynamic>>[]);

  // .maybeSingle() returns null
  final maybeSingleTb = mockTransformBuilder<Map<String, dynamic>?>(null);
  when(() => fb.maybeSingle()).thenAnswer((_) => maybeSingleTb);

  return fb;
}

/// Helper: creates a generic mock filter builder that resolves to [data]
/// when awaited. Useful for `.rpc()` calls where the return type varies
/// (bool, Map, List, null, etc.).
///
/// All standard filter/transform chain methods (eq, neq, select, order, etc.)
/// return the builder itself, so chaining works.
///
/// Usage:
/// ```dart
/// final fb = mockFilterChain<dynamic>(true);
/// when(() => mockSupabase.rpc('my_func', params: {...})).thenReturn(fb);
/// final result = await supabase.rpc('my_func', params: {...}); // returns true
/// ```
MockPostgrestFilterBuilder<T> mockFilterChain<T>(T data) {
  ensureMockFallbacks();
  final fb = MockPostgrestFilterBuilder<T>();

  // All filter methods return self (use thenAnswer because fb implements Future)
  when(() => fb.eq(any(), any())).thenAnswer((_) => fb);
  when(() => fb.neq(any(), any())).thenAnswer((_) => fb);
  when(() => fb.gt(any(), any())).thenAnswer((_) => fb);
  when(() => fb.gte(any(), any())).thenAnswer((_) => fb);
  when(() => fb.lt(any(), any())).thenAnswer((_) => fb);
  when(() => fb.lte(any(), any())).thenAnswer((_) => fb);
  when(() => fb.or(any())).thenAnswer((_) => fb);
  when(() => fb.isFilter(any(), any())).thenAnswer((_) => fb);
  when(() => fb.inFilter(any(), any())).thenAnswer((_) => fb);
  when(() => fb.not(any(), any(), any())).thenAnswer((_) => fb);
  when(() => fb.contains(any(), any())).thenAnswer((_) => fb);

  // Transform methods return self
  when(() => fb.order(any(), ascending: any(named: 'ascending')))
      .thenAnswer((_) => fb);
  when(() => fb.limit(any())).thenAnswer((_) => fb);
  when(() => fb.range(any(), any())).thenAnswer((_) => fb);

  // When `await fb` is called, invoke the continuation callback with data.
  // NOTE: select(), single(), maybeSingle() are NOT stubbed here because
  // their return types differ from T. Use the type-specific helpers
  // (mockListQuery, mockSingleQuery, mockVoidQuery) instead.
  when(() => fb.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as Function;
    return Future<dynamic>.value(onValue(data));
  });

  return fb;
}
