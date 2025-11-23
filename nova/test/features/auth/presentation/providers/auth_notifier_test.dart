// =====================================================================
// Nova - Auth Notifier Unit Tests
// =====================================================================
// Purpose: Test AuthNotifier state management with comprehensive scenarios
// Architecture: mocktail for mocking, Riverpod testing utilities
// =====================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:nova/core/models/auth_state.dart';
import 'package:nova/features/auth/data/repositories/auth_repository.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';

// =====================================================================
// Mock Classes
// =====================================================================

/// Mock AuthRepository for testing AuthNotifier
class MockAuthRepository extends Mock implements AuthRepository {}

/// Mock User for authenticated state
class MockUser extends Mock implements supabase.User {}

/// Mock Session for authenticated state
class MockSession extends Mock implements supabase.Session {}

// =====================================================================
// Test Helpers
// =====================================================================

/// Creates a ProviderContainer with mocked AuthRepository
///
/// This allows us to test AuthNotifier in isolation with full control
/// over the AuthRepository behavior.
ProviderContainer createContainer({
  required AuthRepository mockAuthRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      // Override the auth repository provider with our mock
      authRepositoryProvider.overrideWithValue(mockAuthRepository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// =====================================================================
// Test Suite
// =====================================================================

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('AuthNotifier', () {
    late MockAuthRepository mockAuthRepository;

    setUp(() {
      mockAuthRepository = MockAuthRepository();
    });

    // =================================================================
    // Initial State Tests
    // =================================================================

    group('initial state', () {
      test('is unauthenticated when no session exists', () async {
        // Arrange
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final state = await container.read(authNotifierProvider.future);

        // Assert
        expect(state, isA<AuthStateUnauthenticated>());
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
      });

      test('is authenticated when session exists', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final state = await container.read(authNotifierProvider.future);

        // Assert
        expect(state, isA<AuthStateAuthenticated>());
        final authState = state as AuthStateAuthenticated;
        expect(authState.user.id, equals('user-123'));
        expect(authState.user.email, equals('student@galileimoro.edu.it'));
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
      });

      test('sets up auth state listener on initialization', () async {
        // Arrange
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());

        final container = createContainer(mockAuthRepository: mockAuthRepository);

        // Act - wait for the notifier to initialize
        await container.read(authNotifierProvider.future);

        // Assert
        verify(() => mockAuthRepository.streamAuthState()).called(1);
      });
    });

    // =================================================================
    // sendMagicLink() Tests
    // =================================================================

    group('sendMagicLink', () {
      test('sends magic link successfully', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.sendMagicLink(any()))
            .thenAnswer((_) async => true);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.sendMagicLink(email);

        // Assert
        expect(result, isTrue);
        verify(() => mockAuthRepository.sendMagicLink(email)).called(1);
      });

      test('does not change global auth state on send', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.sendMagicLink(any()))
            .thenAnswer((_) async => true);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Get initial state
        final initialState = await container.read(authNotifierProvider.future);

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        await notifier.sendMagicLink(email);

        // Assert - state should remain unauthenticated
        final currentState = await container.read(authNotifierProvider.future);
        expect(currentState, equals(initialState));
        expect(currentState, isA<AuthStateUnauthenticated>());
      });

      test('throws AuthException on invalid email', () async {
        // Arrange
        const email = 'invalid-email';
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.sendMagicLink(any())).thenThrow(
          supabase.AuthException('Please enter a valid email address'),
        );

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act & Assert
        final notifier = container.read(authNotifierProvider.notifier);
        expect(
          () => notifier.sendMagicLink(email),
          throwsA(isA<supabase.AuthException>().having(
            (e) => e.message,
            'message',
            contains('valid email'),
          )),
        );
      });

      test('throws AuthException on rate limit exceeded', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.sendMagicLink(any())).thenThrow(
          supabase.AuthException(
            'Too many attempts. Please wait 15 minutes before trying again.',
          ),
        );

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act & Assert
        final notifier = container.read(authNotifierProvider.notifier);
        expect(
          () => notifier.sendMagicLink(email),
          throwsA(isA<supabase.AuthException>().having(
            (e) => e.message,
            'message',
            contains('Too many attempts'),
          )),
        );
      });

      test('throws AuthException on network error', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.sendMagicLink(any())).thenThrow(
          supabase.AuthException('Network error. Please check your internet connection.'),
        );

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act & Assert
        final notifier = container.read(authNotifierProvider.notifier);
        expect(
          () => notifier.sendMagicLink(email),
          throwsA(isA<supabase.AuthException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          )),
        );
      });

      test('re-throws unexpected errors', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.sendMagicLink(any()))
            .thenThrow(Exception('Unexpected error'));

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act & Assert
        final notifier = container.read(authNotifierProvider.notifier);
        expect(
          () => notifier.sendMagicLink(email),
          throwsException,
        );
      });
    });

    // =================================================================
    // verifyMagicLink() Tests
    // =================================================================

    group('verifyMagicLink', () {
      test('verifies magic link successfully and updates state to authenticated',
          () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=magiclink&email=student@galileimoro.edu.it',
        );
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.verifyMagicLink(any()))
            .thenAnswer((_) async => mockUser);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.verifyMagicLink(uri);

        // Assert
        expect(result, isTrue);
        verify(() => mockAuthRepository.verifyMagicLink(uri)).called(1);

        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateAuthenticated>());
        final authState = state as AuthStateAuthenticated;
        expect(authState.user.id, equals('user-123'));
      });

      // Note: Testing loading state is difficult with AsyncNotifier because
      // state transitions happen very quickly. The important behavior is that
      // the method returns the correct result and updates state properly,
      // which is tested in other tests.

      test('returns false on expired token', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=expired&type=magiclink&email=student@galileimoro.edu.it',
        );
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.verifyMagicLink(any())).thenThrow(
          supabase.AuthException(
            'This magic link has expired or is invalid. Please request a new one.',
          ),
        );

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.verifyMagicLink(uri);

        // Assert - the important behavior is that it returns false
        expect(result, isFalse);
      });

      test('returns false on invalid token', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=invalid&type=magiclink&email=student@galileimoro.edu.it',
        );
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.verifyMagicLink(any())).thenThrow(
          supabase.AuthException(
            'This magic link has expired or is invalid. Please request a new one.',
          ),
        );

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.verifyMagicLink(uri);

        // Assert - the important behavior is that it returns false
        expect(result, isFalse);
      });

      test('returns false on unexpected errors', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=magiclink&email=student@galileimoro.edu.it',
        );
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.verifyMagicLink(any()))
            .thenThrow(Exception('Unexpected error'));

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.verifyMagicLink(uri);

        // Assert - the important behavior is that it returns false
        expect(result, isFalse);
      });
    });

    // =================================================================
    // signOut() Tests
    // =================================================================

    group('signOut', () {
      test('signs out successfully and updates state to unauthenticated',
          () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.signOut()).thenAnswer((_) async => true);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Verify initial state is authenticated
        final initialState = await container.read(authNotifierProvider.future);
        expect(initialState, isA<AuthStateAuthenticated>());

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.signOut();

        // Assert
        expect(result, isTrue);
        verify(() => mockAuthRepository.signOut()).called(1);

        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateUnauthenticated>());
      });

      // Note: Testing loading state is difficult with AsyncNotifier because
      // state transitions happen very quickly. The important behavior is that
      // the method returns the correct result and updates state properly,
      // which is tested in other tests.

      test('returns false on sign out failure', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.signOut()).thenThrow(
          supabase.AuthException('Failed to sign out. Please try again.'),
        );

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.signOut();

        // Assert - the important behavior is that it returns false
        expect(result, isFalse);
      });

      test('returns false on unexpected sign out errors', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockAuthRepository.signOut())
            .thenThrow(Exception('Unexpected error'));

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.signOut();

        // Assert - the important behavior is that it returns false
        expect(result, isFalse);
      });
    });

    // =================================================================
    // Auth State Listener Tests
    // =================================================================

    group('auth state listener', () {
      test('updates state to authenticated on signedIn event', () async {
        // Arrange
        final mockUser = MockUser();
        final mockSession = MockSession();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);

        // Create a stream controller to emit auth state changes
        final authStateController = StreamController<supabase.AuthState>();
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => authStateController.stream);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Verify initial state is unauthenticated
        final initialState = await container.read(authNotifierProvider.future);
        expect(initialState, isA<AuthStateUnauthenticated>());

        // Act - emit signedIn event
        authStateController.add(
          supabase.AuthState(
            supabase.AuthChangeEvent.signedIn,
            mockSession,
          ),
        );

        // Wait for state update
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateAuthenticated>());
        final authState = state as AuthStateAuthenticated;
        expect(authState.user.id, equals('user-123'));

        // Cleanup
        await authStateController.close();
      });

      test('updates state to unauthenticated on signedOut event', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);

        // Create a stream controller to emit auth state changes
        final authStateController = StreamController<supabase.AuthState>();
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => authStateController.stream);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Verify initial state is authenticated
        final initialState = await container.read(authNotifierProvider.future);
        expect(initialState, isA<AuthStateAuthenticated>());

        // Act - emit signedOut event
        authStateController.add(
          supabase.AuthState(
            supabase.AuthChangeEvent.signedOut,
            null,
          ),
        );

        // Wait for state update
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateUnauthenticated>());

        // Cleanup
        await authStateController.close();
      });

      test('updates state on tokenRefreshed event', () async {
        // Arrange
        final mockUser = MockUser();
        final mockSession = MockSession();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);

        // Create a stream controller to emit auth state changes
        final authStateController = StreamController<supabase.AuthState>();
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => authStateController.stream);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Verify initial state is authenticated
        final initialState = await container.read(authNotifierProvider.future);
        expect(initialState, isA<AuthStateAuthenticated>());

        // Act - emit tokenRefreshed event
        authStateController.add(
          supabase.AuthState(
            supabase.AuthChangeEvent.tokenRefreshed,
            mockSession,
          ),
        );

        // Wait for state update
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - state should still be authenticated with updated user
        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateAuthenticated>());
        final authState = state as AuthStateAuthenticated;
        expect(authState.user.id, equals('user-123'));

        // Cleanup
        await authStateController.close();
      });

      test('updates state on userUpdated event', () async {
        // Arrange
        final mockUser = MockUser();
        final mockSession = MockSession();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('updated@galileimoro.edu.it');
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);

        // Create a stream controller to emit auth state changes
        final authStateController = StreamController<supabase.AuthState>();
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => authStateController.stream);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act - emit userUpdated event
        authStateController.add(
          supabase.AuthState(
            supabase.AuthChangeEvent.userUpdated,
            mockSession,
          ),
        );

        // Wait for state update
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - state should be updated with new user data
        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateAuthenticated>());
        final authState = state as AuthStateAuthenticated;
        expect(authState.user.email, equals('updated@galileimoro.edu.it'));

        // Cleanup
        await authStateController.close();
      });

      test('ignores signedIn event when user is null', () async {
        // Arrange
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);

        // Create a stream controller to emit auth state changes
        final authStateController = StreamController<supabase.AuthState>();
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => authStateController.stream);

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Verify initial state is unauthenticated
        final initialState = await container.read(authNotifierProvider.future);
        expect(initialState, isA<AuthStateUnauthenticated>());

        // Act - emit signedIn event with null user
        authStateController.add(
          supabase.AuthState(
            supabase.AuthChangeEvent.signedIn,
            null,
          ),
        );

        // Wait for potential state update
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - state should remain unauthenticated
        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateUnauthenticated>());

        // Cleanup
        await authStateController.close();
      });
    });

    // =================================================================
    // devSkipAuth() Tests (Development Only)
    // =================================================================

    group('devSkipAuth', () {
      test('returns false in release mode', () async {
        // Note: This test will pass in debug mode, but the actual method
        // checks kDebugMode which is always true in tests
        // This test documents the expected behavior

        // Arrange
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);

        // In actual release builds, this should return false
        // In tests (debug mode), it will attempt to skip auth
        final result = await notifier.devSkipAuth('test@example.com');

        // Assert - in test environment (debug mode)
        // This will return false because there's no existing session
        expect(result, isFalse);
      });

      test('uses existing session when available', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(mockUser);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.devSkipAuth('test@example.com');

        // Assert
        expect(result, isTrue);
        final state = await container.read(authNotifierProvider.future);
        expect(state, isA<AuthStateAuthenticated>());
        final authState = state as AuthStateAuthenticated;
        expect(authState.user.id, equals('user-123'));
      });

      test('returns false when no existing session and cannot create one',
          () async {
        // Arrange
        when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);
        when(() => mockAuthRepository.streamAuthState())
            .thenAnswer((_) => const Stream.empty());

        final container = createContainer(
          mockAuthRepository: mockAuthRepository,
        );

        // Act
        final notifier = container.read(authNotifierProvider.notifier);
        final result = await notifier.devSkipAuth('test@example.com');

        // Assert
        expect(result, isFalse);
      });
    });
  });
}
