/// Tests for AuthState sealed class hierarchy
///
/// Verifies equality, toString, and pattern matching behavior for all states.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:nova/core/models/auth_state.dart';

class MockUser extends Mock implements User {}

void main() {
  group('AuthState', () {
    // =========================================================================
    // AuthStateAuthenticated
    // =========================================================================
    group('AuthStateAuthenticated', () {
      test('stores user and exposes userId in toString (happy)', () {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');

        final state = AuthStateAuthenticated(mockUser);

        expect(state.user, equals(mockUser));
        expect(state.toString(), contains('user-123'));
      });

      test('equality is based on user.id (happy)', () {
        final user1 = MockUser();
        final user2 = MockUser();
        when(() => user1.id).thenReturn('same-id');
        when(() => user2.id).thenReturn('same-id');

        expect(
          AuthStateAuthenticated(user1),
          equals(AuthStateAuthenticated(user2)),
        );
      });

      test('different user IDs are not equal (happy)', () {
        final user1 = MockUser();
        final user2 = MockUser();
        when(() => user1.id).thenReturn('id-1');
        when(() => user2.id).thenReturn('id-2');

        expect(
          AuthStateAuthenticated(user1),
          isNot(equals(AuthStateAuthenticated(user2))),
        );
      });

      test('is not equal to other AuthState types (edge)', () {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');

        final authenticated = AuthStateAuthenticated(mockUser);
        const unauthenticated = AuthStateUnauthenticated();

        expect(authenticated, isNot(equals(unauthenticated)));
      });

      test('hashCode is consistent with equality (edge)', () {
        final user1 = MockUser();
        final user2 = MockUser();
        when(() => user1.id).thenReturn('same-id');
        when(() => user2.id).thenReturn('same-id');

        expect(
          AuthStateAuthenticated(user1).hashCode,
          equals(AuthStateAuthenticated(user2).hashCode),
        );
      });

      test('identical instances are equal (edge)', () {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-123');
        final state = AuthStateAuthenticated(mockUser);

        expect(state, equals(state));
      });
    });

    // =========================================================================
    // AuthStateUnauthenticated
    // =========================================================================
    group('AuthStateUnauthenticated', () {
      test('all instances are equal (happy)', () {
        expect(
          const AuthStateUnauthenticated(),
          equals(const AuthStateUnauthenticated()),
        );
      });

      test('toString returns expected format (edge)', () {
        expect(
          const AuthStateUnauthenticated().toString(),
          equals('AuthStateUnauthenticated()'),
        );
      });
    });

    // =========================================================================
    // AuthStateLoading
    // =========================================================================
    group('AuthStateLoading', () {
      test('default has null message (happy)', () {
        const state = AuthStateLoading();
        expect(state.message, isNull);
      });

      test('stores optional message (happy)', () {
        const state = AuthStateLoading('Verifying token...');
        expect(state.message, equals('Verifying token...'));
      });

      test('equality includes message comparison (edge)', () {
        expect(
          const AuthStateLoading('msg1'),
          isNot(equals(const AuthStateLoading('msg2'))),
        );
        expect(
          const AuthStateLoading('msg1'),
          equals(const AuthStateLoading('msg1')),
        );
      });

      test('loading with and without message are not equal (edge)', () {
        expect(
          const AuthStateLoading(),
          isNot(equals(const AuthStateLoading('loading'))),
        );
      });
    });

    // =========================================================================
    // AuthStateGuest
    // =========================================================================
    group('AuthStateGuest', () {
      test('all instances are equal (happy)', () {
        expect(
          const AuthStateGuest(),
          equals(const AuthStateGuest()),
        );
      });

      test('is not equal to AuthStateUnauthenticated (edge)', () {
        expect(
          const AuthStateGuest(),
          isNot(equals(const AuthStateUnauthenticated())),
        );
      });
    });

    // =========================================================================
    // AuthStateError
    // =========================================================================
    group('AuthStateError', () {
      test('stores error message (happy)', () {
        const state = AuthStateError('Something went wrong');
        expect(state.message, equals('Something went wrong'));
      });

      test('equality is based on message (edge)', () {
        expect(
          const AuthStateError('error1'),
          isNot(equals(const AuthStateError('error2'))),
        );
        expect(
          const AuthStateError('same'),
          equals(const AuthStateError('same')),
        );
      });

      test('toString contains message (edge)', () {
        const state = AuthStateError('Network error');
        expect(state.toString(), contains('Network error'));
      });
    });

    // =========================================================================
    // Pattern Matching (race condition equivalent: type safety)
    // =========================================================================
    group('pattern matching', () {
      test('switch expression covers all states (race: exhaustiveness)', () {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('x');
        final states = <AuthState>[
          AuthStateAuthenticated(mockUser),
          const AuthStateUnauthenticated(),
          const AuthStateLoading(),
          const AuthStateGuest(),
          const AuthStateError('err'),
        ];

        for (final state in states) {
          final label = switch (state) {
            AuthStateAuthenticated() => 'authenticated',
            AuthStateUnauthenticated() => 'unauthenticated',
            AuthStateLoading() => 'loading',
            AuthStateGuest() => 'guest',
            AuthStateError() => 'error',
          };
          expect(label, isNotEmpty);
        }
      });

      test('destructuring extracts fields correctly (race: type narrowing)', () {
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('user-abc');

        final AuthState state = AuthStateAuthenticated(mockUser);

        if (state case AuthStateAuthenticated(:final user)) {
          expect(user.id, equals('user-abc'));
        } else {
          fail('Pattern should match AuthStateAuthenticated');
        }
      });
    });
  });
}
