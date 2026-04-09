/// Tests for core_providers.dart
///
/// Verifies that core providers work correctly with mocked Supabase client.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/core/providers/core_providers.dart';
import '../../mocks/mock_supabase.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  group('Core Providers', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late ProviderContainer container;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
    });

    tearDown(() {
      container.dispose();
    });

    group('currentUserIdProvider', () {
      test('returns user ID when authenticated', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn(TestUserIds.student1);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final userId = container.read(currentUserIdProvider);

        // Assert
        expect(userId, equals(TestUserIds.student1));
      });

      test('returns empty string when not authenticated', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final userId = container.read(currentUserIdProvider);

        // Assert
        expect(userId, isEmpty);
      });
    });

    group('currentUserIdOrNullProvider', () {
      test('returns user ID when authenticated', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn(TestUserIds.student1);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final userId = container.read(currentUserIdOrNullProvider);

        // Assert
        expect(userId, equals(TestUserIds.student1));
      });

      test('returns null when not authenticated', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final userId = container.read(currentUserIdOrNullProvider);

        // Assert
        expect(userId, isNull);
      });
    });

    group('isAuthenticatedProvider', () {
      test('returns true when user is authenticated', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn(TestUserIds.student1);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final isAuthenticated = container.read(isAuthenticatedProvider);

        // Assert
        expect(isAuthenticated, isTrue);
      });

      test('returns false when user is not authenticated', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final isAuthenticated = container.read(isAuthenticatedProvider);

        // Assert
        expect(isAuthenticated, isFalse);
      });
    });

    group('currentUserEmailProvider', () {
      test('returns email when authenticated', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.email).thenReturn(TestUserEmails.student1);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final email = container.read(currentUserEmailProvider);

        // Assert
        expect(email, equals(TestUserEmails.student1));
      });

      test('returns null when not authenticated', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final email = container.read(currentUserEmailProvider);

        // Assert
        expect(email, isNull);
      });
    });

    // =========================================================================
    // ADDITIONAL EDGE CASE TESTS
    // =========================================================================

    group('currentUserProvider', () {
      test('returns User object when authenticated (happy)', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn(TestUserIds.student1);
        when(() => mockUser.email).thenReturn(TestUserEmails.student1);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final user = container.read(currentUserProvider);

        // Assert
        expect(user, isNotNull);
        expect(user!.id, equals(TestUserIds.student1));
      });

      test('returns null when not authenticated (happy)', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final user = container.read(currentUserProvider);

        // Assert
        expect(user, isNull);
      });
    });

    group('provider consistency (edge cases)', () {
      test('all auth providers agree when authenticated', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn(TestUserIds.student1);
        when(() => mockUser.email).thenReturn(TestUserEmails.student1);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act & Assert
        expect(container.read(isAuthenticatedProvider), isTrue);
        expect(container.read(currentUserIdProvider), isNotEmpty);
        expect(container.read(currentUserIdOrNullProvider), isNotNull);
        expect(container.read(currentUserEmailProvider), isNotNull);
        expect(container.read(currentUserProvider), isNotNull);
      });

      test('all auth providers agree when not authenticated', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act & Assert
        expect(container.read(isAuthenticatedProvider), isFalse);
        expect(container.read(currentUserIdProvider), isEmpty);
        expect(container.read(currentUserIdOrNullProvider), isNull);
        expect(container.read(currentUserEmailProvider), isNull);
        expect(container.read(currentUserProvider), isNull);
      });

      test('currentUserIdProvider returns empty string not null when unauthenticated', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final userId = container.read(currentUserIdProvider);

        // Assert - explicitly verify type behavior
        expect(userId, isA<String>());
        expect(userId, equals(''));
        expect(userId.isEmpty, isTrue);
      });

      test('currentUserEmailProvider returns null not empty string when user has no email', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn(TestUserIds.student1);
        when(() => mockUser.email).thenReturn(null);
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
        );

        // Act
        final email = container.read(currentUserEmailProvider);

        // Assert
        expect(email, isNull);
      });
    });
  });
}
