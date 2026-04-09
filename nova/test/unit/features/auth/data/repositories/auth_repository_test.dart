import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/exceptions/nova_exceptions.dart';
import 'package:nova/features/auth/data/repositories/auth_repository.dart';
import '../../../../../mocks/mock_supabase.dart';

// ============================================================================
// ADDITIONAL MOCKS
// ============================================================================

class MockSession extends Mock implements Session {}

class FakeUri extends Fake implements Uri {}

void main() {
  late AuthRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    repository = AuthRepository(supabase: mockSupabase);
  });

  setUpAll(() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(OtpType.magiclink);
  });

  // ==========================================================================
  // sendMagicLink - Happy paths
  // ==========================================================================

  group('sendMagicLink', () {
    test('returns true on successful magic link send', () async {
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async {});

      final result =
          await repository.sendMagicLink('mario.rossi@galileimoro.edu.it');

      expect(result, true);
      verify(() => mockAuth.signInWithOtp(
            email: 'mario.rossi@galileimoro.edu.it',
            emailRedirectTo: 'https://nova-app.shop/auth/callback',
          )).called(1);
    });

    test('normalizes email (trim + lowercase)', () async {
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async {});

      await repository.sendMagicLink('  Mario.Rossi@GALILEIMORO.edu.it  ');

      verify(() => mockAuth.signInWithOtp(
            email: 'mario.rossi@galileimoro.edu.it',
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).called(1);
    });

    // Edge: invalid email format
    test('throws AuthException for invalid email', () async {
      expect(
        () => repository.sendMagicLink('not-an-email'),
        throwsA(isA<AuthException>()),
      );
    });

    // Edge: empty email
    test('throws AuthException for empty email', () async {
      expect(
        () => repository.sendMagicLink(''),
        throwsA(isA<AuthException>()),
      );
    });

    // Edge: rate limit
    test('throws RateLimitException on rate limit error', () async {
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenThrow(AuthException('Rate limit exceeded'));

      expect(
        () => repository.sendMagicLink('test@galileimoro.edu.it'),
        throwsA(isA<RateLimitException>()),
      );
    });

    // Edge: generic AuthException wrapping
    test('wraps unknown errors as AuthException', () async {
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenThrow(Exception('Unexpected'));

      expect(
        () => repository.sendMagicLink('test@galileimoro.edu.it'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  // ==========================================================================
  // verifyMagicLink - Happy + Edge
  // ==========================================================================

  group('verifyMagicLink', () {
    test('exchanges PKCE code for session', () async {
      final mockUser = MockUser();
      final mockSession = MockSession();
      when(() => mockUser.id).thenReturn('user-001');
      when(() => mockUser.email).thenReturn('mario@galileimoro.edu.it');
      when(() => mockAuth.currentUser).thenReturn(null);

      when(() => mockAuth.exchangeCodeForSession(any()))
          .thenAnswer((_) async => AuthSessionUrlResponse(
                session: mockSession,
                redirectType: null,
              ));
      when(() => mockSession.user).thenReturn(mockUser);

      final uri =
          Uri.parse('novaapp://auth/callback?code=test-code-123');
      final result = await repository.verifyMagicLink(uri);

      expect(result.id, 'user-001');
    });

    test('verifies token_hash with OTP', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user-001');
      when(() => mockAuth.currentUser).thenReturn(null);

      when(() => mockAuth.verifyOTP(
            tokenHash: 'hash123',
            type: OtpType.magiclink,
            email: 'test@galileimoro.edu.it',
          )).thenAnswer((_) async => AuthResponse(
            user: mockUser,
            session: null,
          ));

      final uri = Uri.parse(
        'novaapp://auth/callback?token_hash=hash123&type=magiclink&email=test@galileimoro.edu.it',
      );
      final result = await repository.verifyMagicLink(uri);

      expect(result.id, 'user-001');
    });

    // Edge: missing email with token_hash
    test('throws AuthException when token_hash present but no email',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final uri = Uri.parse(
        'novaapp://auth/callback?token_hash=hash123&type=magiclink',
      );

      expect(
        () => repository.verifyMagicLink(uri),
        throwsA(isA<AuthException>()),
      );
    });

    // Edge: expired/invalid link
    test('throws on expired magic link', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.refreshSession())
          .thenThrow(AuthException('Session expired'));

      final uri = Uri.parse('novaapp://auth/callback');

      expect(
        () => repository.verifyMagicLink(uri),
        throwsA(isA<AuthException>()),
      );
    });
  });

  // ==========================================================================
  // signOut
  // ==========================================================================

  group('signOut', () {
    test('returns true on successful sign out', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result, true);
    });

    // Edge: sign out failure
    test('throws AuthException on sign out failure', () async {
      when(() => mockAuth.signOut())
          .thenThrow(AuthException('Network error'));

      expect(
        () => repository.signOut(),
        throwsA(isA<AuthException>()),
      );
    });
  });

  // ==========================================================================
  // getCurrentUser
  // ==========================================================================

  group('getCurrentUser', () {
    test('returns user when authenticated', () {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user-001');
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final result = repository.getCurrentUser();

      expect(result, isNotNull);
      expect(result!.id, 'user-001');
    });

    test('returns null when not authenticated', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = repository.getCurrentUser();

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // streamAuthState
  // ==========================================================================

  group('streamAuthState', () {
    test('returns stream from auth.onAuthStateChange', () {
      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => controller.stream);

      final stream = repository.streamAuthState();

      expect(stream, isA<Stream<AuthState>>());
      controller.close();
    });
  });

  // ==========================================================================
  // Race conditions
  // ==========================================================================

  group('race conditions', () {
    test('signs out existing user before verifying new magic link', () async {
      // Simulate existing session
      final existingUser = MockUser();
      when(() => existingUser.id).thenReturn('old-user');
      when(() => mockAuth.currentUser).thenReturn(existingUser);
      when(() => mockAuth.signOut(scope: SignOutScope.local))
          .thenAnswer((_) async {});

      final newUser = MockUser();
      when(() => newUser.id).thenReturn('new-user');
      when(() => newUser.email).thenReturn('new@galileimoro.edu.it');

      final mockSession = MockSession();
      when(() => mockSession.user).thenReturn(newUser);
      when(() => mockAuth.exchangeCodeForSession('new-code'))
          .thenAnswer((_) async => AuthSessionUrlResponse(
                session: mockSession,
                redirectType: null,
              ));

      final uri = Uri.parse('novaapp://auth/callback?code=new-code');
      final result = await repository.verifyMagicLink(uri);

      expect(result.id, 'new-user');
      verify(() => mockAuth.signOut(scope: SignOutScope.local)).called(1);
    });

    test('handles concurrent token refresh during API call gracefully',
        () async {
      // If sendMagicLink is called while a token refresh is happening,
      // the auth library should handle it, but we test the repo doesn't crash
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async {
        // Simulate slight delay as if token refresh happened
        await Future.delayed(const Duration(milliseconds: 10));
      });

      final result =
          await repository.sendMagicLink('test@galileimoro.edu.it');
      expect(result, true);
    });
  });
}
