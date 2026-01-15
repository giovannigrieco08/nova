/// Mock Supabase client for testing
///
/// Provides mocked versions of Supabase client and related classes
/// for unit and widget testing without actual network calls.

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

/// Mock PostgrestFilterBuilder
class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {}

/// Mock PostgrestTransformBuilder
class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}

/// Mock SupabaseStorageClient
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

/// Mock StorageFileApi
class MockStorageFileApi extends Mock implements StorageFileApi {}

/// Mock RealtimeChannel
class MockRealtimeChannel extends Mock implements RealtimeChannel {}

/// Create a fully configured mock Supabase client
///
/// Returns a [MockSupabaseClient] with auth mocked to return a test user.
/// Configure additional mocks as needed for specific tests.
///
/// Usage:
/// ```dart
/// final mockSupabase = createMockSupabaseClient(userId: 'test-user-123');
/// ```
MockSupabaseClient createMockSupabaseClient({
  String? userId,
  String? userEmail,
}) {
  final mockClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();

  // Configure auth
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

/// Setup fake classes for mocktail
///
/// Call this in setUpAll() to register fallback values for mocktail.
void setupMocktailFallbacks() {
  // Register any fallback values needed for mocktail here
  // registerFallbackValue(FakeMyClass());
}
