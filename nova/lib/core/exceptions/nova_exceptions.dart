/// Core Exception Hierarchy for Nova
///
/// All feature-specific exceptions inherit from base NovaException.
/// Provides consistent error handling across the entire application.
///
/// Usage:
/// ```dart
/// try {
///   await repository.fetchData();
/// } on NovaException catch (e) {
///   final result = errorHandler.handleError(e);
///   showSnackbar(result.userMessage);
/// }
/// ```
library;

/// Base exception class for all Nova errors
///
/// Features should extend this with their own base exception
/// (e.g., ChatException extends NovaException)
abstract class NovaException implements Exception {
  /// User-friendly message (for display in UI)
  final String message;

  /// Technical message (for logging/debugging)
  final String? technicalMessage;

  /// Stack trace at point of error
  final StackTrace? stackTrace;

  /// Original exception (if wrapping another)
  final Object? originalException;

  /// Error code for categorization
  String get code;

  /// Whether this error should be reported to Crashlytics
  bool get shouldReport => true;

  /// Whether this is a recoverable error (user can retry)
  bool get isRecoverable => true;

  const NovaException(
    this.message, {
    this.technicalMessage,
    this.stackTrace,
    this.originalException,
  });

  @override
  String toString() => '$runtimeType: $message';

  /// Convert to map for structured logging
  Map<String, dynamic> toLogMap() => {
        'type': runtimeType.toString(),
        'code': code,
        'message': message,
        if (technicalMessage != null) 'technicalMessage': technicalMessage,
        'isRecoverable': isRecoverable,
        'shouldReport': shouldReport,
      };
}

// =============================================================================
// Network Exceptions
// =============================================================================

/// Network connectivity issues or general network errors
class NetworkException extends NovaException {
  @override
  String get code => 'NETWORK_ERROR';

  @override
  bool get isRecoverable => true;

  const NetworkException(
    super.message, {
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

/// Request timed out
class TimeoutException extends NetworkException {
  final Duration? timeout;

  @override
  String get code => 'TIMEOUT';

  const TimeoutException(
    super.message, {
    this.timeout,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Authentication Exceptions
// =============================================================================

/// User not authenticated (missing or invalid JWT)
class UnauthorizedException extends NovaException {
  @override
  String get code => 'UNAUTHORIZED';

  @override
  bool get isRecoverable => false; // Requires re-login

  const UnauthorizedException(
    super.message, {
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

/// User authenticated but not allowed to perform action (RLS policy violation)
class ForbiddenException extends NovaException {
  final String? requiredRole;

  @override
  String get code => 'FORBIDDEN';

  @override
  bool get isRecoverable => false;

  const ForbiddenException(
    super.message, {
    this.requiredRole,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Validation Exceptions
// =============================================================================

/// Validation errors (invalid input, format errors)
class ValidationException extends NovaException {
  final String field;
  final dynamic invalidValue;

  @override
  String get code => 'VALIDATION_ERROR';

  @override
  bool get shouldReport => false; // User error, not app error

  const ValidationException(
    super.message, {
    required this.field,
    this.invalidValue,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

/// Profanity or inappropriate content detected
class ProfanityException extends ValidationException {
  @override
  String get code => 'PROFANITY_DETECTED';

  const ProfanityException(
    super.message, {
    required super.field,
    super.invalidValue,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Rate Limiting Exceptions
// =============================================================================

/// Rate limit exceeded (spam prevention)
class RateLimitException extends NovaException {
  final Duration? retryAfter;

  @override
  String get code => 'RATE_LIMIT';

  @override
  bool get shouldReport => false; // Expected behavior

  const RateLimitException(
    super.message, {
    this.retryAfter,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Resource Exceptions
// =============================================================================

/// Resource not found
class NotFoundException extends NovaException {
  final String resourceType;
  final String? resourceId;

  @override
  String get code => 'NOT_FOUND';

  @override
  bool get isRecoverable => false;

  const NotFoundException(
    super.message, {
    required this.resourceType,
    this.resourceId,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

/// Conflict error (duplicate, unique constraint violation)
class ConflictException extends NovaException {
  final String conflictType;

  @override
  String get code => 'CONFLICT';

  const ConflictException(
    super.message, {
    required this.conflictType,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Server/Infrastructure Exceptions
// =============================================================================

/// Server error (5xx, database error)
class ServerException extends NovaException {
  final int? statusCode;
  final String? serverMessage;

  @override
  String get code => 'SERVER_ERROR';

  @override
  bool get shouldReport => true;

  const ServerException(
    super.message, {
    this.statusCode,
    this.serverMessage,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

/// Local cache/storage errors
class CacheException extends NovaException {
  final String operation;

  @override
  String get code => 'CACHE_ERROR';

  @override
  bool get shouldReport => true;

  const CacheException(
    super.message, {
    required this.operation,
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Offline Exceptions
// =============================================================================

/// Operation queued for offline sync or device is offline
class OfflineException extends NovaException {
  @override
  String get code => 'OFFLINE';

  @override
  bool get shouldReport => false;

  @override
  bool get isRecoverable => true;

  const OfflineException(
    super.message, {
    super.technicalMessage,
    super.stackTrace,
    super.originalException,
  });
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Create NovaException from Supabase PostgrestException code and message
NovaException novaExceptionFromSupabaseError(
  String? code,
  String message, [
  StackTrace? stackTrace,
]) {
  switch (code) {
    // Unique constraint violation
    case '23505':
      return ConflictException(
        'Elemento gia esistente',
        conflictType: 'unique_constraint',
        technicalMessage: message,
        stackTrace: stackTrace,
      );

    // Foreign key violation
    case '23503':
      return NotFoundException(
        'Risorsa collegata non trovata',
        resourceType: 'referenced_resource',
        technicalMessage: message,
        stackTrace: stackTrace,
      );

    // Custom DB exception (profanity, rate limit, etc.)
    case 'P0001':
      final lowerMessage = message.toLowerCase();
      if (lowerMessage.contains('rate limit')) {
        return RateLimitException(
          'Troppi tentativi. Attendi qualche minuto.',
          retryAfter: const Duration(minutes: 5),
          technicalMessage: message,
          stackTrace: stackTrace,
        );
      }
      if (lowerMessage.contains('inappropriate') ||
          lowerMessage.contains('profanity')) {
        return ProfanityException(
          'Il contenuto contiene linguaggio inappropriato',
          field: 'content',
          technicalMessage: message,
          stackTrace: stackTrace,
        );
      }
      return ValidationException(
        'Dati non validi',
        field: 'unknown',
        technicalMessage: message,
        stackTrace: stackTrace,
      );

    // RLS policy violation
    case '42501':
      return ForbiddenException(
        'Non hai i permessi per questa azione',
        technicalMessage: message,
        stackTrace: stackTrace,
      );

    // Row not found
    case 'PGRST116':
    case 'PGRST204':
      return NotFoundException(
        'Elemento non trovato',
        resourceType: 'resource',
        technicalMessage: message,
        stackTrace: stackTrace,
      );

    default:
      // Network errors (PostgreSQL code starting with 08)
      if (code?.startsWith('08') ?? false) {
        return NetworkException(
          'Errore di connessione. Verifica la tua rete.',
          technicalMessage: message,
          stackTrace: stackTrace,
        );
      }

      // Server errors
      if ((code?.startsWith('XX') ?? false) || (code?.startsWith('58') ?? false)) {
        return ServerException(
          'Errore del server. Riprova piu tardi.',
          serverMessage: message,
          technicalMessage: 'Code: $code',
          stackTrace: stackTrace,
        );
      }

      // Default to server exception for unknown codes
      return ServerException(
        'Errore imprevisto. Riprova.',
        serverMessage: message,
        technicalMessage: 'Code: $code',
        stackTrace: stackTrace,
      );
  }
}

/// Create NovaException from HTTP status code
NovaException novaExceptionFromHttpStatus(
  int statusCode,
  String message, [
  StackTrace? stackTrace,
]) {
  switch (statusCode) {
    case 400:
      return ValidationException(
        'Richiesta non valida',
        field: 'request',
        technicalMessage: message,
        stackTrace: stackTrace,
      );
    case 401:
      return UnauthorizedException(
        'Sessione scaduta. Effettua nuovamente il login.',
        technicalMessage: message,
        stackTrace: stackTrace,
      );
    case 403:
      return ForbiddenException(
        'Non hai i permessi per questa azione',
        technicalMessage: message,
        stackTrace: stackTrace,
      );
    case 404:
      return NotFoundException(
        'Elemento non trovato',
        resourceType: 'resource',
        technicalMessage: message,
        stackTrace: stackTrace,
      );
    case 409:
      return ConflictException(
        'Conflitto: elemento gia esistente',
        conflictType: 'http_conflict',
        technicalMessage: message,
        stackTrace: stackTrace,
      );
    case 429:
      return RateLimitException(
        'Troppi tentativi. Attendi un minuto.',
        retryAfter: const Duration(seconds: 60),
        technicalMessage: message,
        stackTrace: stackTrace,
      );
    default:
      if (statusCode >= 500) {
        return ServerException(
          'Errore del server. Riprova piu tardi.',
          statusCode: statusCode,
          technicalMessage: message,
          stackTrace: stackTrace,
        );
      }
      return ServerException(
        'Errore HTTP: $statusCode',
        statusCode: statusCode,
        technicalMessage: message,
        stackTrace: stackTrace,
      );
  }
}
