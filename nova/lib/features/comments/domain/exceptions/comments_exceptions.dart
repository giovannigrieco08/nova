/// Exception Hierarchy for Comments Feature
///
/// All exceptions inherit from base CommentException for easy catch blocks.
/// Each exception type maps to specific error scenarios from Supabase/repository.

/// Base exception class for all comment-related errors
abstract class CommentException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  const CommentException(this.message, [this.stackTrace]);

  @override
  String toString() => 'CommentException: $message';
}

/// Network connectivity issues or timeouts
class NetworkException extends CommentException {
  const NetworkException(
    String message, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'NetworkException: $message';
}

/// User not authenticated (missing or invalid JWT)
class UnauthorizedException extends CommentException {
  const UnauthorizedException(
    String message, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// User authenticated but not allowed to perform action (RLS policy violation)
class ForbiddenException extends CommentException {
  final String? requiredRole;

  const ForbiddenException(
    String message, [
    this.requiredRole,
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'ForbiddenException: $message'
      '${requiredRole != null ? ' (requires role: $requiredRole)' : ''}';
}

/// Validation errors (text length, profanity, invalid input)
class ValidationException extends CommentException {
  final String field;
  final dynamic invalidValue;

  const ValidationException(
    String message,
    this.field, [
    this.invalidValue,
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() =>
      'ValidationException: $message (field: $field, value: $invalidValue)';
}

/// Rate limit exceeded (spam prevention)
class RateLimitException extends CommentException {
  final Duration retryAfter;

  const RateLimitException(
    String message,
    this.retryAfter, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'RateLimitException: $message '
      '(retry after: ${retryAfter.inSeconds}s)';
}

/// Resource not found (comment, event, user doesn't exist)
class NotFoundException extends CommentException {
  final String resourceType;
  final String resourceId;

  const NotFoundException(
    String message,
    this.resourceType,
    this.resourceId, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() =>
      'NotFoundException: $message ($resourceType ID: $resourceId)';
}

/// Conflict error (duplicate like, duplicate report, unique constraint violation)
class ConflictException extends CommentException {
  final String conflictType;

  const ConflictException(
    String message,
    this.conflictType, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'ConflictException: $message (type: $conflictType)';
}

/// Server error (Supabase 5xx, database error, unexpected failure)
class ServerException extends CommentException {
  final int? statusCode;
  final String? serverMessage;

  const ServerException(
    String message, [
    this.statusCode,
    this.serverMessage,
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'ServerException: $message'
      '${statusCode != null ? ' (status: $statusCode)' : ''}'
      '${serverMessage != null ? ' - $serverMessage' : ''}';
}

/// Local cache/storage errors (Hive database issues)
class CacheException extends CommentException {
  final String operation;

  const CacheException(
    String message,
    this.operation, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  @override
  String toString() => 'CacheException: $message (operation: $operation)';
}

/// Helper functions for exception creation

/// Create exception from Supabase error code and message
CommentException fromSupabaseError(
  String code,
  String message, [
  StackTrace? stackTrace,
]) {
  // PostgreSQL error codes
  switch (code) {
    case '23505': // Unique constraint violation
      return ConflictException(message, 'unique_constraint', stackTrace);

    case '23503': // Foreign key violation
      return NotFoundException(
        message,
        'referenced_resource',
        'unknown',
        stackTrace,
      );

    case 'P0001': // Custom exception (profanity, rate limit)
      if (message.contains('Rate limit exceeded')) {
        // Extract duration from message if available
        final duration = Duration(minutes: 5); // Default
        return RateLimitException(message, duration, stackTrace);
      } else if (message.contains('inappropriate language')) {
        return ValidationException(message, 'text', null, stackTrace);
      }
      return ValidationException(message, 'unknown', null, stackTrace);

    case '42501': // Insufficient privilege (RLS policy)
      return ForbiddenException(message, null, stackTrace);

    case 'PGRST116': // Row not found
      return NotFoundException(message, 'resource', 'unknown', stackTrace);

    case 'PGRST204': // No content (not really an error, but handled)
      return NotFoundException(message, 'resource', 'unknown', stackTrace);

    default:
      // Network errors
      if (code.startsWith('08')) {
        return NetworkException(message, stackTrace);
      }

      // Server errors (5xx equivalent)
      if (code.startsWith('XX') || code.startsWith('58')) {
        return ServerException(message, null, null, stackTrace);
      }

      // Default to server exception for unknown codes
      return ServerException(
        'Unknown error: $message',
        null,
        'Code: $code',
        stackTrace,
      );
  }
}

/// Create exception from HTTP status code
CommentException fromHttpStatus(
  int statusCode,
  String message, [
  StackTrace? stackTrace,
]) {
  switch (statusCode) {
    case 400:
      return ValidationException(message, 'request', null, stackTrace);
    case 401:
      return UnauthorizedException(message, stackTrace);
    case 403:
      return ForbiddenException(message, null, stackTrace);
    case 404:
      return NotFoundException(message, 'resource', 'unknown', stackTrace);
    case 409:
      return ConflictException(message, 'conflict', stackTrace);
    case 429:
      return RateLimitException(
        message,
        const Duration(seconds: 60),
        stackTrace,
      );
    case >= 500:
      return ServerException(message, statusCode, null, stackTrace);
    default:
      return ServerException(
        'HTTP error: $message',
        statusCode,
        null,
        stackTrace,
      );
  }
}
