// =====================================================================
// Nova - Auth Repository Unit Tests
// =====================================================================
// Purpose: Test AuthRepository with comprehensive scenarios
// Architecture: mocktail for mocking Supabase dependencies
// =====================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/auth/data/repositories/auth_repository.dart';

// =====================================================================
// Mock Classes
// =====================================================================

/// Mock SupabaseClient for testing
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Mock GoTrueClient for auth operations
class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Mock AuthResponse for OTP operations
class MockAuthResponse extends Mock implements AuthResponse {}

/// Mock AuthSessionUrlResponse for getSessionFromUrl
class MockAuthSessionUrlResponse extends Mock implements AuthSessionUrlResponse {}

/// Mock User for authenticated state
class MockUser extends Mock implements User {}

/// Mock Session for authenticated state
class MockSession extends Mock implements Session {}

// =====================================================================
// Test Suite
// =====================================================================

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(OtpType.magiclink);
  });

  group('AuthRepository', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late AuthRepository authRepository;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();

      // Setup default behavior for mockSupabase.auth
      when(() => mockSupabase.auth).thenReturn(mockAuth);

      // Create repository with mocked Supabase
      authRepository = AuthRepository(supabase: mockSupabase);
    });

    // =================================================================
    // getCurrentUser() Tests
    // =================================================================

    group('getCurrentUser', () {
      test('returns User when session exists', () {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = authRepository.getCurrentUser();

        // Assert
        expect(result, isNotNull);
        expect(result?.id, equals('user-123'));
        expect(result?.email, equals('student@galileimoro.edu.it'));
        verify(() => mockAuth.currentUser).called(1);
      });

      test('returns null when no session exists', () {
        // Arrange
        when(() => mockAuth.currentUser).thenReturn(null);

        // Act
        final result = authRepository.getCurrentUser();

        // Assert
        expect(result, isNull);
        verify(() => mockAuth.currentUser).called(1);
      });
    });

    // =================================================================
    // sendMagicLink() Tests
    // =================================================================

    group('sendMagicLink', () {
      test('sends magic link successfully with valid email', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuth.signInWithOtp(
              email: any(named: 'email'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenAnswer((_) async => MockAuthResponse());

        // Act
        final result = await authRepository.sendMagicLink(email);

        // Assert
        expect(result, isTrue);
        verify(() => mockAuth.signInWithOtp(
              email: email,
              emailRedirectTo: 'novaapp://auth/callback',
            )).called(1);
      });

      test('normalizes email before sending (uppercase to lowercase)', () async {
        // Arrange
        const email = 'Student@GALILEIMORO.edu.it';
        const normalizedEmail = 'student@galileimoro.edu.it';
        when(() => mockAuth.signInWithOtp(
              email: any(named: 'email'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenAnswer((_) async => MockAuthResponse());

        // Act
        await authRepository.sendMagicLink(email);

        // Assert
        verify(() => mockAuth.signInWithOtp(
              email: normalizedEmail,
              emailRedirectTo: 'novaapp://auth/callback',
            )).called(1);
      });

      test('normalizes email before sending (trim whitespace)', () async {
        // Arrange
        const email = '  student@galileimoro.edu.it  ';
        const normalizedEmail = 'student@galileimoro.edu.it';
        when(() => mockAuth.signInWithOtp(
              email: any(named: 'email'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenAnswer((_) async => MockAuthResponse());

        // Act
        await authRepository.sendMagicLink(email);

        // Assert
        verify(() => mockAuth.signInWithOtp(
              email: normalizedEmail,
              emailRedirectTo: 'novaapp://auth/callback',
            )).called(1);
      });

      test('throws AuthException when email is invalid (empty)', () async {
        // Act & Assert
        expect(
          () => authRepository.sendMagicLink(''),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('required'),
          )),
        );
      });

      test('throws AuthException when email format is invalid', () async {
        // Act & Assert
        expect(
          () => authRepository.sendMagicLink('not-an-email'),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('valid email'),
          )),
        );
      });

      test('throws AuthException when rate limit exceeded', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuth.signInWithOtp(
              email: any(named: 'email'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenThrow(
          AuthException(
            'Email rate limit exceeded',
            statusCode: '429',
          ),
        );

        // Act & Assert
        expect(
          () => authRepository.sendMagicLink(email),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Too many attempts'),
          )),
        );
      });

      test('throws AuthException on network error', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuth.signInWithOtp(
              email: any(named: 'email'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenThrow(
          AuthException('Network error', statusCode: '500'),
        );

        // Act & Assert
        expect(
          () => authRepository.sendMagicLink(email),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          )),
        );
      });

      test('wraps unexpected errors in AuthException', () async {
        // Arrange
        const email = 'student@galileimoro.edu.it';
        when(() => mockAuth.signInWithOtp(
              email: any(named: 'email'),
              emailRedirectTo: any(named: 'emailRedirectTo'),
            )).thenThrow(Exception('Unexpected error'));

        // Act & Assert
        expect(
          () => authRepository.sendMagicLink(email),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Failed to send magic link'),
          )),
        );
      });
    });

    // =================================================================
    // verifyMagicLink() Tests
    // =================================================================

    group('verifyMagicLink', () {
      test('verifies magic link successfully with custom scheme URL', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=magiclink&email=student@galileimoro.edu.it',
        );
        final mockUser = MockUser();
        final mockResponse = MockAuthResponse();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockResponse.user).thenReturn(mockUser);
        when(() => mockAuth.verifyOTP(
              tokenHash: 'abc123',
              type: OtpType.magiclink,
              email: 'student@galileimoro.edu.it',
            )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await authRepository.verifyMagicLink(uri);

        // Assert
        expect(result, isNotNull);
        expect(result.id, equals('user-123'));
        expect(result.email, equals('student@galileimoro.edu.it'));
        verify(() => mockAuth.verifyOTP(
              tokenHash: 'abc123',
              type: OtpType.magiclink,
              email: 'student@galileimoro.edu.it',
            )).called(1);
      });

      test('verifies magic link successfully with HTTPS URL', () async {
        // Arrange
        final uri = Uri.parse(
          'https://project.supabase.co/auth/v1/verify?token=xyz789&type=magiclink',
        );
        final mockUser = MockUser();
        final mockSession = MockSession();
        final mockResponse = MockAuthSessionUrlResponse();
        when(() => mockUser.id).thenReturn('user-456');
        when(() => mockUser.email).thenReturn('test@galileimoro.edu.it');
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockResponse.session).thenReturn(mockSession);
        when(() => mockAuth.getSessionFromUrl(any()))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await authRepository.verifyMagicLink(uri);

        // Assert
        expect(result, isNotNull);
        expect(result.id, equals('user-456'));
        expect(result.email, equals('test@galileimoro.edu.it'));
        verify(() => mockAuth.getSessionFromUrl(uri)).called(1);
      });

      test('throws AuthException when token_hash is missing', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?type=magiclink&email=student@galileimoro.edu.it',
        );

        // Act & Assert
        // Note: The repository's _handleAuthException maps "invalid" errors to generic message
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('expired or is invalid'),
          )),
        );
      });

      test('throws AuthException when email is missing', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=magiclink',
        );

        // Act & Assert
        // Note: The repository's _handleAuthException maps "invalid" errors to generic message
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('expired or is invalid'),
          )),
        );
      });

      test('throws AuthException when type is not magiclink', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=signup&email=student@galileimoro.edu.it',
        );

        // Act & Assert
        // Note: The repository's _handleAuthException maps "invalid" errors to generic message
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('expired or is invalid'),
          )),
        );
      });

      test('throws AuthException when token is expired', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=expired&type=magiclink&email=student@galileimoro.edu.it',
        );
        when(() => mockAuth.verifyOTP(
              tokenHash: 'expired',
              type: OtpType.magiclink,
              email: 'student@galileimoro.edu.it',
            )).thenThrow(
          AuthException('Token expired', statusCode: '400'),
        );

        // Act & Assert
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('expired or is invalid'),
          )),
        );
      });

      test('throws AuthException when token is invalid', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=invalid&type=magiclink&email=student@galileimoro.edu.it',
        );
        when(() => mockAuth.verifyOTP(
              tokenHash: 'invalid',
              type: OtpType.magiclink,
              email: 'student@galileimoro.edu.it',
            )).thenThrow(
          AuthException('Invalid token', statusCode: '400'),
        );

        // Act & Assert
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('expired or is invalid'),
          )),
        );
      });

      test('throws AuthException when verification returns null user', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=magiclink&email=student@galileimoro.edu.it',
        );
        final mockResponse = MockAuthResponse();
        when(() => mockResponse.user).thenReturn(null);
        when(() => mockAuth.verifyOTP(
              tokenHash: 'abc123',
              type: OtpType.magiclink,
              email: 'student@galileimoro.edu.it',
            )).thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('verification failed'),
          )),
        );
      });

      test('wraps unexpected errors in AuthException', () async {
        // Arrange
        final uri = Uri.parse(
          'novaapp://auth/callback?token_hash=abc123&type=magiclink&email=student@galileimoro.edu.it',
        );
        when(() => mockAuth.verifyOTP(
              tokenHash: 'abc123',
              type: OtpType.magiclink,
              email: 'student@galileimoro.edu.it',
            )).thenThrow(Exception('Unexpected error'));

        // Act & Assert
        expect(
          () => authRepository.verifyMagicLink(uri),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Failed to verify magic link'),
          )),
        );
      });
    });

    // =================================================================
    // signOut() Tests
    // =================================================================

    group('signOut', () {
      test('signs out successfully', () async {
        // Arrange
        when(() => mockAuth.signOut()).thenAnswer((_) async => {});

        // Act
        final result = await authRepository.signOut();

        // Assert
        expect(result, isTrue);
        verify(() => mockAuth.signOut()).called(1);
      });

      test('throws AuthException on sign out failure', () async {
        // Arrange
        when(() => mockAuth.signOut()).thenThrow(
          AuthException('Sign out failed', statusCode: '500'),
        );

        // Act & Assert
        expect(
          () => authRepository.signOut(),
          throwsA(isA<AuthException>()),
        );
      });

      test('wraps unexpected errors in AuthException', () async {
        // Arrange
        when(() => mockAuth.signOut()).thenThrow(Exception('Unexpected error'));

        // Act & Assert
        expect(
          () => authRepository.signOut(),
          throwsA(isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Failed to sign out'),
          )),
        );
      });
    });

    // =================================================================
    // streamAuthState() Tests
    // =================================================================

    group('streamAuthState', () {
      test('returns auth state stream', () {
        // Arrange
        final mockStream = Stream<AuthState>.empty();
        when(() => mockAuth.onAuthStateChange).thenAnswer((_) => mockStream);

        // Act
        final result = authRepository.streamAuthState();

        // Assert
        expect(result, equals(mockStream));
        verify(() => mockAuth.onAuthStateChange).called(1);
      });

      test('emits auth state changes on sign in', () async {
        // Arrange
        final mockUser = MockUser();
        final mockSession = MockSession();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockUser.email).thenReturn('student@galileimoro.edu.it');
        when(() => mockSession.user).thenReturn(mockUser);

        final authState = AuthState(
          AuthChangeEvent.signedIn,
          mockSession,
        );
        final mockStream = Stream<AuthState>.value(authState);
        when(() => mockAuth.onAuthStateChange).thenAnswer((_) => mockStream);

        // Act
        final result = authRepository.streamAuthState();

        // Assert
        expect(
          result,
          emits(predicate<AuthState>(
            (state) =>
                state.event == AuthChangeEvent.signedIn &&
                state.session?.user.id == 'user-123',
          )),
        );
      });

      test('emits auth state changes on sign out', () async {
        // Arrange
        final authState = AuthState(
          AuthChangeEvent.signedOut,
          null,
        );
        final mockStream = Stream<AuthState>.value(authState);
        when(() => mockAuth.onAuthStateChange).thenAnswer((_) => mockStream);

        // Act
        final result = authRepository.streamAuthState();

        // Assert
        expect(
          result,
          emits(predicate<AuthState>(
            (state) =>
                state.event == AuthChangeEvent.signedOut &&
                state.session == null,
          )),
        );
      });

      test('emits auth state changes on token refresh', () async {
        // Arrange
        final mockUser = MockUser();
        final mockSession = MockSession();
        when(() => mockUser.id).thenReturn('user-123');
        when(() => mockSession.user).thenReturn(mockUser);

        final authState = AuthState(
          AuthChangeEvent.tokenRefreshed,
          mockSession,
        );
        final mockStream = Stream<AuthState>.value(authState);
        when(() => mockAuth.onAuthStateChange).thenAnswer((_) => mockStream);

        // Act
        final result = authRepository.streamAuthState();

        // Assert
        expect(
          result,
          emits(predicate<AuthState>(
            (state) =>
                state.event == AuthChangeEvent.tokenRefreshed &&
                state.session?.user.id == 'user-123',
          )),
        );
      });
    });
  });
}
