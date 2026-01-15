/// Centralized Error Handler Service
///
/// Responsibilities:
/// - Translate exceptions to user-friendly messages
/// - Log errors appropriately (debug vs production)
/// - Report to Crashlytics (production only)
/// - Provide error recovery suggestions
///
/// Usage:
/// ```dart
/// final errorHandler = ref.watch(errorHandlerProvider);
/// try {
///   await repository.fetchData();
/// } catch (e, stack) {
///   final result = errorHandler.handleError(e, stack);
///   showSnackbar(result.userMessage);
/// }
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../exceptions/nova_exceptions.dart';

/// Error severity levels for UI presentation
enum ErrorSeverity {
  /// User error (validation, rate limit) - show snackbar
  low,

  /// Recoverable error (network, timeout) - show retry dialog
  medium,

  /// Critical error (server, auth) - show error screen
  high,

  /// Fatal error (crash) - report and restart
  fatal,
}

/// Result of error handling with UI-ready information
class ErrorResult {
  /// User-friendly message to display
  final String userMessage;

  /// Error severity for UI decisions
  final ErrorSeverity severity;

  /// Whether user can retry the action
  final bool canRetry;

  /// Suggested action label (e.g., "Riprova", "Vai al login")
  final String? actionLabel;

  /// The original NovaException for further processing
  final NovaException? exception;

  const ErrorResult({
    required this.userMessage,
    required this.severity,
    this.canRetry = false,
    this.actionLabel,
    this.exception,
  });

  @override
  String toString() =>
      'ErrorResult(message: $userMessage, severity: $severity, canRetry: $canRetry)';
}

/// Centralized error handling service
class ErrorHandlerService {
  final bool _isProduction;

  ErrorHandlerService({
    bool? isProduction,
  }) : _isProduction = isProduction ?? kReleaseMode;

  /// Handle any exception and return user-friendly result
  ///
  /// This is the main entry point for error handling.
  /// Converts any exception to NovaException, logs it,
  /// and returns an ErrorResult for UI presentation.
  ErrorResult handleError(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    // Convert to NovaException if not already
    final novaException = _toNovaException(error, stackTrace);

    // Log the error
    _logError(novaException);

    // Return user-friendly result
    return _toErrorResult(novaException);
  }

  /// Convert any exception to NovaException
  NovaException _toNovaException(Object error, StackTrace? stackTrace) {
    // Already a NovaException
    if (error is NovaException) {
      return error;
    }

    // Handle Supabase PostgrestException
    if (error is PostgrestException) {
      return novaExceptionFromSupabaseError(
        error.code,
        error.message,
        stackTrace,
      );
    }

    // Handle Supabase AuthException
    if (error is AuthException) {
      return _fromAuthException(error, stackTrace);
    }

    // Handle Supabase StorageException
    if (error is StorageException) {
      return ServerException(
        'Errore nel caricamento del file',
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    // Handle generic Dart exceptions
    if (error is FormatException) {
      return ValidationException(
        'Formato dati non valido',
        field: 'data',
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    // Generic exception wrapper
    return ServerException(
      'Si e verificato un errore. Riprova.',
      technicalMessage: error.toString(),
      stackTrace: stackTrace,
      originalException: error,
    );
  }

  /// Convert AuthException to NovaException
  NovaException _fromAuthException(
    AuthException error,
    StackTrace? stackTrace,
  ) {
    final message = error.message.toLowerCase();

    if (message.contains('rate limit')) {
      return RateLimitException(
        'Troppi tentativi. Attendi 15 minuti.',
        retryAfter: const Duration(minutes: 15),
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    if (message.contains('invalid') || message.contains('expired')) {
      return UnauthorizedException(
        'Sessione scaduta. Effettua nuovamente il login.',
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    if (message.contains('not authorized') || message.contains('domain')) {
      return ForbiddenException(
        'Usa il tuo indirizzo email scolastico (@galileimoro.edu.it)',
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    if (message.contains('network') || message.contains('connection')) {
      return NetworkException(
        'Errore di rete. Verifica la connessione.',
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    if (message.contains('otp') || message.contains('link')) {
      return UnauthorizedException(
        'Il link di accesso non e valido o e scaduto. Richiedi un nuovo link.',
        technicalMessage: error.message,
        stackTrace: stackTrace,
        originalException: error,
      );
    }

    return UnauthorizedException(
      'Errore di autenticazione',
      technicalMessage: error.message,
      stackTrace: stackTrace,
      originalException: error,
    );
  }

  /// Convert NovaException to ErrorResult for UI
  ///
  /// Note: More specific exception types MUST come before their parent types
  /// in the switch expression (e.g., TimeoutException before NetworkException).
  ErrorResult _toErrorResult(NovaException exception) {
    return switch (exception) {
      // TimeoutException MUST come before NetworkException (it extends NetworkException)
      TimeoutException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.medium,
          canRetry: true,
          actionLabel: 'Riprova',
          exception: exception,
        ),
      NetworkException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.medium,
          canRetry: true,
          actionLabel: 'Riprova',
          exception: exception,
        ),
      UnauthorizedException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.high,
          canRetry: false,
          actionLabel: 'Vai al login',
          exception: exception,
        ),
      ForbiddenException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.medium,
          canRetry: false,
          exception: exception,
        ),
      // ProfanityException MUST come before ValidationException (it extends ValidationException)
      ProfanityException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.low,
          canRetry: false,
          exception: exception,
        ),
      ValidationException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.low,
          canRetry: false,
          exception: exception,
        ),
      RateLimitException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.low,
          canRetry: false,
          exception: exception,
        ),
      NotFoundException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.medium,
          canRetry: false,
          exception: exception,
        ),
      ConflictException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.low,
          canRetry: false,
          exception: exception,
        ),
      ServerException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.high,
          canRetry: true,
          actionLabel: 'Riprova',
          exception: exception,
        ),
      CacheException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.medium,
          canRetry: true,
          actionLabel: 'Riprova',
          exception: exception,
        ),
      OfflineException() => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.low,
          canRetry: false,
          exception: exception,
        ),
      _ => ErrorResult(
          userMessage: exception.message,
          severity: ErrorSeverity.medium,
          canRetry: true,
          actionLabel: 'Riprova',
          exception: exception,
        ),
    };
  }

  /// Log error based on environment
  void _logError(NovaException exception) {
    if (_isProduction) {
      // Production: minimal logging (Crashlytics handles reporting)
      // Only log critical errors
      if (exception.shouldReport) {
        // Crashlytics integration would go here
        // FirebaseCrashlytics.instance.recordError(...)
      }
    }
    // Development logging removed - use debugger or Crashlytics instead
  }

  /// Log a non-error event for debugging
  void logEvent(String event, [Map<String, dynamic>? data]) {
    // Logging removed - use debugger instead
  }
}

/// Riverpod provider for ErrorHandlerService
///
/// Usage:
/// ```dart
/// final errorHandler = ref.watch(errorHandlerProvider);
/// final result = errorHandler.handleError(error, stackTrace);
/// ```
final errorHandlerProvider = Provider<ErrorHandlerService>((ref) {
  return ErrorHandlerService();
});
