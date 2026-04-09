/// Tests for Nova exception hierarchy
///
/// Covers all exception types, helper functions, and property behaviors.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/exceptions/nova_exceptions.dart';

void main() {
  group('NovaExceptions', () {
    // =========================================================================
    // HAPPY PATH - Exception properties
    // =========================================================================

    group('NetworkException', () {
      test('has correct code and properties (happy)', () {
        const exception = NetworkException(
          'Network error',
          technicalMessage: 'Connection refused',
        );

        expect(exception.code, equals('NETWORK_ERROR'));
        expect(exception.message, equals('Network error'));
        expect(exception.technicalMessage, equals('Connection refused'));
        expect(exception.isRecoverable, isTrue);
        expect(exception.shouldReport, isTrue);
      });

      test('toString returns class name and message (happy)', () {
        const exception = NetworkException('Test error');
        expect(exception.toString(), equals('NetworkException: Test error'));
      });
    });

    group('TimeoutException', () {
      test('extends NetworkException with timeout field (happy)', () {
        const exception = TimeoutException(
          'Request timed out',
          timeout: Duration(seconds: 30),
        );

        expect(exception, isA<NetworkException>());
        expect(exception.code, equals('TIMEOUT'));
        expect(exception.timeout, equals(const Duration(seconds: 30)));
      });
    });

    group('UnauthorizedException', () {
      test('is not recoverable (happy)', () {
        const exception = UnauthorizedException('Session expired');

        expect(exception.code, equals('UNAUTHORIZED'));
        expect(exception.isRecoverable, isFalse);
      });
    });

    group('ForbiddenException', () {
      test('stores required role (happy)', () {
        const exception = ForbiddenException(
          'Not allowed',
          requiredRole: 'moderator',
        );

        expect(exception.code, equals('FORBIDDEN'));
        expect(exception.requiredRole, equals('moderator'));
        expect(exception.isRecoverable, isFalse);
      });
    });

    group('ValidationException', () {
      test('stores field and value, does not report (happy)', () {
        const exception = ValidationException(
          'Invalid email',
          field: 'email',
          invalidValue: 'bad@',
        );

        expect(exception.code, equals('VALIDATION_ERROR'));
        expect(exception.field, equals('email'));
        expect(exception.invalidValue, equals('bad@'));
        expect(exception.shouldReport, isFalse);
      });
    });

    // =========================================================================
    // Exception hierarchy
    // =========================================================================

    group('hierarchy', () {
      test('ProfanityException extends ValidationException (happy)', () {
        const exception = ProfanityException(
          'Bad word',
          field: 'content',
        );

        expect(exception, isA<ValidationException>());
        expect(exception, isA<NovaException>());
        expect(exception.code, equals('PROFANITY_DETECTED'));
      });

      test('TimeoutException extends NetworkException (edge)', () {
        const exception = TimeoutException('timed out');

        expect(exception, isA<NetworkException>());
        expect(exception, isA<NovaException>());
      });

      test('all exceptions implement Exception interface (edge)', () {
        final exceptions = <NovaException>[
          const NetworkException('test'),
          const TimeoutException('test'),
          const UnauthorizedException('test'),
          const ForbiddenException('test'),
          const ValidationException('test', field: 'f'),
          const ProfanityException('test', field: 'f'),
          const RateLimitException('test'),
          const NotFoundException('test', resourceType: 'r'),
          const ConflictException('test', conflictType: 'c'),
          const ServerException('test'),
          const CacheException('test', operation: 'o'),
          const OfflineException('test'),
        ];

        for (final e in exceptions) {
          expect(e, isA<Exception>());
          expect(e, isA<NovaException>());
          expect(e.code, isNotEmpty);
          expect(e.message, isNotEmpty);
        }
      });
    });

    // =========================================================================
    // toLogMap
    // =========================================================================

    group('toLogMap', () {
      test('includes required fields (happy)', () {
        const exception = ServerException(
          'Server error',
          statusCode: 500,
          technicalMessage: 'Internal server error',
        );

        final map = exception.toLogMap();

        expect(map['type'], equals('ServerException'));
        expect(map['code'], equals('SERVER_ERROR'));
        expect(map['message'], equals('Server error'));
        expect(map['technicalMessage'], equals('Internal server error'));
        expect(map['isRecoverable'], isTrue);
        expect(map['shouldReport'], isTrue);
      });

      test('omits null technicalMessage (edge)', () {
        const exception = NetworkException('test');

        final map = exception.toLogMap();

        expect(map.containsKey('technicalMessage'), isFalse);
      });
    });

    // =========================================================================
    // Specific exception properties
    // =========================================================================

    group('RateLimitException', () {
      test('stores retryAfter and does not report (edge)', () {
        const exception = RateLimitException(
          'Too many attempts',
          retryAfter: Duration(minutes: 15),
        );

        expect(exception.retryAfter, equals(const Duration(minutes: 15)));
        expect(exception.shouldReport, isFalse);
      });
    });

    group('NotFoundException', () {
      test('stores resourceType and resourceId (edge)', () {
        const exception = NotFoundException(
          'Not found',
          resourceType: 'event',
          resourceId: 'event-123',
        );

        expect(exception.resourceType, equals('event'));
        expect(exception.resourceId, equals('event-123'));
        expect(exception.isRecoverable, isFalse);
      });
    });

    group('OfflineException', () {
      test('does not report and is recoverable (edge)', () {
        const exception = OfflineException('Offline mode');

        expect(exception.shouldReport, isFalse);
        expect(exception.isRecoverable, isTrue);
        expect(exception.code, equals('OFFLINE'));
      });
    });

    // =========================================================================
    // novaExceptionFromSupabaseError
    // =========================================================================

    group('novaExceptionFromSupabaseError', () {
      test('23505 returns ConflictException (happy)', () {
        final result = novaExceptionFromSupabaseError('23505', 'duplicate key');

        expect(result, isA<ConflictException>());
        expect((result as ConflictException).conflictType,
            equals('unique_constraint'));
      });

      test('23503 returns NotFoundException (happy)', () {
        final result =
            novaExceptionFromSupabaseError('23503', 'foreign key violation');

        expect(result, isA<NotFoundException>());
      });

      test('42501 returns ForbiddenException (happy)', () {
        final result =
            novaExceptionFromSupabaseError('42501', 'RLS policy violation');

        expect(result, isA<ForbiddenException>());
      });

      test('PGRST116 returns NotFoundException (happy)', () {
        final result =
            novaExceptionFromSupabaseError('PGRST116', 'no rows found');

        expect(result, isA<NotFoundException>());
      });

      test('P0001 with rate limit returns RateLimitException (edge)', () {
        final result = novaExceptionFromSupabaseError(
            'P0001', 'Rate limit exceeded for this action');

        expect(result, isA<RateLimitException>());
      });

      test('P0001 with profanity returns ProfanityException (edge)', () {
        final result = novaExceptionFromSupabaseError(
            'P0001', 'Inappropriate content detected');

        expect(result, isA<ProfanityException>());
      });

      test('P0001 with unknown message returns ValidationException (edge)', () {
        final result =
            novaExceptionFromSupabaseError('P0001', 'some custom check failed');

        expect(result, isA<ValidationException>());
      });

      test('08xxx code returns NetworkException (edge)', () {
        final result = novaExceptionFromSupabaseError(
            '08001', 'connection refused');

        expect(result, isA<NetworkException>());
      });

      test('XX/58 codes return ServerException (edge)', () {
        expect(
          novaExceptionFromSupabaseError('XX000', 'internal error'),
          isA<ServerException>(),
        );
        expect(
          novaExceptionFromSupabaseError('58030', 'io error'),
          isA<ServerException>(),
        );
      });

      test('unknown code returns ServerException (edge)', () {
        final result =
            novaExceptionFromSupabaseError('99999', 'unknown');

        expect(result, isA<ServerException>());
      });

      test('null code returns ServerException (edge)', () {
        final result = novaExceptionFromSupabaseError(null, 'no code');

        expect(result, isA<ServerException>());
      });
    });

    // =========================================================================
    // novaExceptionFromHttpStatus
    // =========================================================================

    group('novaExceptionFromHttpStatus', () {
      test('400 returns ValidationException (happy)', () {
        expect(
          novaExceptionFromHttpStatus(400, 'bad request'),
          isA<ValidationException>(),
        );
      });

      test('401 returns UnauthorizedException (happy)', () {
        expect(
          novaExceptionFromHttpStatus(401, 'unauthorized'),
          isA<UnauthorizedException>(),
        );
      });

      test('403 returns ForbiddenException (happy)', () {
        expect(
          novaExceptionFromHttpStatus(403, 'forbidden'),
          isA<ForbiddenException>(),
        );
      });

      test('404 returns NotFoundException (happy)', () {
        expect(
          novaExceptionFromHttpStatus(404, 'not found'),
          isA<NotFoundException>(),
        );
      });

      test('409 returns ConflictException (edge)', () {
        expect(
          novaExceptionFromHttpStatus(409, 'conflict'),
          isA<ConflictException>(),
        );
      });

      test('429 returns RateLimitException (edge)', () {
        final result = novaExceptionFromHttpStatus(429, 'too many');
        expect(result, isA<RateLimitException>());
        expect((result as RateLimitException).retryAfter,
            equals(const Duration(seconds: 60)));
      });

      test('500 returns ServerException (edge)', () {
        final result = novaExceptionFromHttpStatus(500, 'server error');
        expect(result, isA<ServerException>());
        expect((result as ServerException).statusCode, equals(500));
      });

      test('502 returns ServerException for 5xx range (edge)', () {
        expect(
          novaExceptionFromHttpStatus(502, 'bad gateway'),
          isA<ServerException>(),
        );
      });

      test('unknown status returns ServerException (edge)', () {
        final result = novaExceptionFromHttpStatus(418, 'teapot');
        expect(result, isA<ServerException>());
      });
    });
  });
}
