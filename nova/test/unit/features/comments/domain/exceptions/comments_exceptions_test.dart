import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/domain/exceptions/comments_exceptions.dart';

void main() {
  group('CommentException hierarchy', () {
    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('exception creation and toString', () {
      test('NetworkException has correct message and toString', () {
        const e = NetworkException('Connection timeout');
        expect(e.message, 'Connection timeout');
        expect(e.toString(), 'NetworkException: Connection timeout');
        expect(e, isA<CommentException>());
      });

      test('UnauthorizedException has correct toString', () {
        const e = UnauthorizedException('Invalid JWT');
        expect(e.toString(), 'UnauthorizedException: Invalid JWT');
      });

      test('ForbiddenException includes requiredRole when provided', () {
        const e = ForbiddenException('Not allowed', 'moderator');
        expect(e.requiredRole, 'moderator');
        expect(e.toString(), contains('requires role: moderator'));
      });

      test('ForbiddenException omits role when null', () {
        const e = ForbiddenException('Not allowed');
        expect(e.toString(), 'ForbiddenException: Not allowed');
        expect(e.toString(), isNot(contains('requires role')));
      });

      test('ValidationException includes field and value', () {
        const e = ValidationException('Too long', 'text', 'abc');
        expect(e.field, 'text');
        expect(e.invalidValue, 'abc');
        expect(e.toString(), contains('field: text'));
        expect(e.toString(), contains('value: abc'));
      });

      test('RateLimitException includes retry duration', () {
        const e = RateLimitException(
          'Too many requests',
          Duration(seconds: 30),
        );
        expect(e.retryAfter, const Duration(seconds: 30));
        expect(e.toString(), contains('retry after: 30s'));
      });

      test('NotFoundException includes resource info', () {
        const e = NotFoundException('Not found', 'comment', 'c-123');
        expect(e.resourceType, 'comment');
        expect(e.resourceId, 'c-123');
        expect(e.toString(), contains('comment ID: c-123'));
      });

      test('ConflictException includes conflict type', () {
        const e = ConflictException('Duplicate', 'unique_constraint');
        expect(e.conflictType, 'unique_constraint');
        expect(e.toString(), contains('type: unique_constraint'));
      });

      test('ServerException includes status code and server message', () {
        const e = ServerException('Error', 500, 'Internal');
        expect(e.statusCode, 500);
        expect(e.serverMessage, 'Internal');
        expect(e.toString(), contains('status: 500'));
        expect(e.toString(), contains('Internal'));
      });

      test('ServerException omits optional fields when null', () {
        const e = ServerException('Error');
        expect(e.toString(), 'ServerException: Error');
      });

      test('CacheException includes operation', () {
        const e = CacheException('Read failed', 'get');
        expect(e.operation, 'get');
        expect(e.toString(), contains('operation: get'));
      });
    });

    group('all exceptions implement CommentException', () {
      test('each subclass is a CommentException', () {
        expect(const NetworkException('e'), isA<CommentException>());
        expect(const UnauthorizedException('e'), isA<CommentException>());
        expect(const ForbiddenException('e'), isA<CommentException>());
        expect(const ValidationException('e', 'f'), isA<CommentException>());
        expect(
          const RateLimitException('e', Duration.zero),
          isA<CommentException>(),
        );
        expect(
          const NotFoundException('e', 't', 'i'),
          isA<CommentException>(),
        );
        expect(const ConflictException('e', 't'), isA<CommentException>());
        expect(const ServerException('e'), isA<CommentException>());
        expect(const CacheException('e', 'o'), isA<CommentException>());
      });
    });

    // ========================================================================
    // fromSupabaseError
    // ========================================================================

    group('fromSupabaseError', () {
      test('23505 returns ConflictException', () {
        final e = fromSupabaseError('23505', 'Duplicate key');
        expect(e, isA<ConflictException>());
        expect((e as ConflictException).conflictType, 'unique_constraint');
      });

      test('23503 returns NotFoundException', () {
        final e = fromSupabaseError('23503', 'FK violation');
        expect(e, isA<NotFoundException>());
      });

      test('P0001 with rate limit returns RateLimitException', () {
        final e = fromSupabaseError('P0001', 'Rate limit exceeded');
        expect(e, isA<RateLimitException>());
      });

      test('P0001 with inappropriate language returns ValidationException', () {
        final e = fromSupabaseError('P0001', 'Contains inappropriate language');
        expect(e, isA<ValidationException>());
      });

      test('P0001 with other message returns ValidationException', () {
        final e = fromSupabaseError('P0001', 'Some custom error');
        expect(e, isA<ValidationException>());
      });

      test('42501 returns ForbiddenException', () {
        final e = fromSupabaseError('42501', 'RLS violation');
        expect(e, isA<ForbiddenException>());
      });

      test('PGRST116 returns NotFoundException', () {
        final e = fromSupabaseError('PGRST116', 'Row not found');
        expect(e, isA<NotFoundException>());
      });

      test('PGRST204 returns NotFoundException', () {
        final e = fromSupabaseError('PGRST204', 'No content');
        expect(e, isA<NotFoundException>());
      });

      test('08xxx returns NetworkException', () {
        final e = fromSupabaseError('08001', 'Connection refused');
        expect(e, isA<NetworkException>());
      });

      test('XX/58 codes return ServerException', () {
        expect(fromSupabaseError('XX000', 'Internal'), isA<ServerException>());
        expect(fromSupabaseError('58000', 'System'), isA<ServerException>());
      });

      test('unknown code returns ServerException with details', () {
        final e = fromSupabaseError('99999', 'Unknown');
        expect(e, isA<ServerException>());
        expect(e.message, contains('Unknown error'));
      });
    });

    // ========================================================================
    // fromHttpStatus
    // ========================================================================

    group('fromHttpStatus', () {
      test('400 returns ValidationException', () {
        expect(fromHttpStatus(400, 'Bad'), isA<ValidationException>());
      });

      test('401 returns UnauthorizedException', () {
        expect(fromHttpStatus(401, 'Unauth'), isA<UnauthorizedException>());
      });

      test('403 returns ForbiddenException', () {
        expect(fromHttpStatus(403, 'Forbidden'), isA<ForbiddenException>());
      });

      test('404 returns NotFoundException', () {
        expect(fromHttpStatus(404, 'Not found'), isA<NotFoundException>());
      });

      test('409 returns ConflictException', () {
        expect(fromHttpStatus(409, 'Conflict'), isA<ConflictException>());
      });

      test('429 returns RateLimitException with 60s retry', () {
        final e = fromHttpStatus(429, 'Too many') as RateLimitException;
        expect(e.retryAfter, const Duration(seconds: 60));
      });

      test('500+ returns ServerException with status code', () {
        final e = fromHttpStatus(502, 'Bad gateway') as ServerException;
        expect(e.statusCode, 502);
      });

      test('unknown status returns ServerException', () {
        final e = fromHttpStatus(302, 'Redirect') as ServerException;
        expect(e.message, contains('HTTP error'));
        expect(e.statusCode, 302);
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('stackTrace is preserved when provided', () {
        final trace = StackTrace.current;
        final e = NetworkException('err', trace);
        expect(e.stackTrace, trace);
      });

      test('stackTrace is null by default', () {
        const e = NetworkException('err');
        expect(e.stackTrace, isNull);
      });

      test('base CommentException toString works', () {
        const e = NetworkException('test msg');
        // NetworkException overrides toString, but base would show CommentException
        expect(e.toString(), contains('test msg'));
      });
    });
  });
}
