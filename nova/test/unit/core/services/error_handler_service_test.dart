/// Tests for ErrorHandlerService
///
/// Verifies error translation, severity mapping, and retry logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/core/services/error_handler_service.dart';
import 'package:nova/core/exceptions/nova_exceptions.dart';

void main() {
  group('ErrorHandlerService', () {
    late ErrorHandlerService service;

    setUp(() {
      // Use non-production mode for testing
      service = ErrorHandlerService(isProduction: false);
    });

    // =========================================================================
    // HAPPY PATH - Direct NovaException handling
    // =========================================================================

    group('handleError with NovaException types', () {
      test('NetworkException returns medium severity with retry (happy)', () {
        const error = NetworkException('Errore di rete');

        final result = service.handleError(error);

        expect(result.userMessage, equals('Errore di rete'));
        expect(result.severity, equals(ErrorSeverity.medium));
        expect(result.canRetry, isTrue);
        expect(result.actionLabel, equals('Riprova'));
        expect(result.exception, equals(error));
      });

      test('UnauthorizedException returns high severity without retry (happy)', () {
        const error = UnauthorizedException('Sessione scaduta');

        final result = service.handleError(error);

        expect(result.userMessage, equals('Sessione scaduta'));
        expect(result.severity, equals(ErrorSeverity.high));
        expect(result.canRetry, isFalse);
        expect(result.actionLabel, equals('Vai al login'));
      });

      test('ValidationException returns low severity without retry (happy)', () {
        const error = ValidationException('Campo non valido', field: 'email');

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.low));
        expect(result.canRetry, isFalse);
      });

      test('ServerException returns high severity with retry (happy)', () {
        const error = ServerException('Errore del server', statusCode: 500);

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.high));
        expect(result.canRetry, isTrue);
        expect(result.actionLabel, equals('Riprova'));
      });
    });

    // =========================================================================
    // EDGE CASES - Exception conversion
    // =========================================================================

    group('handleError with non-Nova exceptions', () {
      test('FormatException is converted to ValidationException (edge)', () {
        final error = const FormatException('bad format');

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.low));
        expect(result.exception, isA<ValidationException>());
      });

      test('generic Exception is wrapped as ServerException (edge)', () {
        final error = Exception('unknown error');

        final result = service.handleError(error);

        expect(result.exception, isA<ServerException>());
        expect(result.severity, equals(ErrorSeverity.high));
        expect(result.canRetry, isTrue);
      });

      test('String error is wrapped as ServerException (edge)', () {
        const error = 'raw string error';

        final result = service.handleError(error);

        expect(result.exception, isA<ServerException>());
      });

      test('AuthException with rate limit message maps to RateLimitException (edge)', () {
        final error = AuthException('Rate limit exceeded');

        final result = service.handleError(error);

        expect(result.exception, isA<RateLimitException>());
        expect(result.severity, equals(ErrorSeverity.low));
      });
    });

    // =========================================================================
    // Specific exception subtypes
    // =========================================================================

    group('exception subtype ordering', () {
      test('TimeoutException (extends NetworkException) gets correct severity', () {
        const error = TimeoutException(
          'Request timed out',
          timeout: Duration(seconds: 30),
        );

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.medium));
        expect(result.canRetry, isTrue);
      });

      test('ProfanityException (extends ValidationException) gets correct severity', () {
        const error = ProfanityException(
          'Linguaggio inappropriato',
          field: 'content',
        );

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.low));
        expect(result.canRetry, isFalse);
      });

      test('ForbiddenException returns medium severity without retry', () {
        const error = ForbiddenException('Non autorizzato');

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.medium));
        expect(result.canRetry, isFalse);
      });

      test('CacheException returns medium severity with retry', () {
        const error = CacheException('Cache error', operation: 'read');

        final result = service.handleError(error);

        expect(result.severity, equals(ErrorSeverity.medium));
        expect(result.canRetry, isTrue);
      });
    });

    // =========================================================================
    // ErrorResult
    // =========================================================================

    group('ErrorResult', () {
      test('toString formats correctly', () {
        const result = ErrorResult(
          userMessage: 'Test message',
          severity: ErrorSeverity.low,
          canRetry: true,
        );

        expect(result.toString(), contains('Test message'));
        expect(result.toString(), contains('low'));
        expect(result.toString(), contains('true'));
      });
    });

    // =========================================================================
    // AuthException mapping
    // =========================================================================

    group('AuthException message parsing', () {
      test('invalid/expired maps to UnauthorizedException', () {
        final error = AuthException('Token invalid or expired');
        final result = service.handleError(error);
        expect(result.exception, isA<UnauthorizedException>());
      });

      test('domain restriction maps to ForbiddenException', () {
        final error = AuthException('Email domain not authorized');
        final result = service.handleError(error);
        expect(result.exception, isA<ForbiddenException>());
      });

      test('network error maps to NetworkException', () {
        final error = AuthException('Network connection failed');
        final result = service.handleError(error);
        expect(result.exception, isA<NetworkException>());
      });

      test('otp/link message maps to UnauthorizedException', () {
        final error = AuthException('OTP link has expired');
        final result = service.handleError(error);
        expect(result.exception, isA<UnauthorizedException>());
      });

      test('unknown auth error maps to generic UnauthorizedException', () {
        final error = AuthException('Something completely unknown happened');
        final result = service.handleError(error);
        expect(result.exception, isA<UnauthorizedException>());
      });
    });

    // =========================================================================
    // Production mode
    // =========================================================================

    group('production mode', () {
      test('production service can be created without error', () {
        final prodService = ErrorHandlerService(isProduction: true);
        const error = NetworkException('test');
        final result = prodService.handleError(error);
        expect(result.userMessage, equals('test'));
      });
    });
  });
}
