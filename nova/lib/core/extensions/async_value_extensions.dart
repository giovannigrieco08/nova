/// Extensions for Riverpod AsyncValue with unified error handling
///
/// Provides helper methods for building widgets with automatic
/// error handling using ErrorHandlerService.
///
/// Usage:
/// ```dart
/// asyncValue.buildWithErrorHandling(
///   data: (data) => DataWidget(data),
///   loading: () => LoadingWidget(),
///   errorHandler: ref.watch(errorHandlerProvider),
///   onRetry: () => ref.invalidate(myProvider),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/error_handler_service.dart';
import '../theme/nova_colors.dart';
import '../theme/nova_spacing.dart';
import '../theme/nova_typography.dart';

/// Extension methods for AsyncValue with error handling
extension AsyncValueErrorHandling<T> on AsyncValue<T> {
  /// Handle error with ErrorHandlerService and return ErrorResult
  ///
  /// Returns null if the AsyncValue is not in error state.
  ErrorResult? handleError(ErrorHandlerService errorHandler) {
    return whenOrNull(
      error: (error, stackTrace) => errorHandler.handleError(error, stackTrace),
    );
  }

  /// Build widget with automatic error handling
  ///
  /// This method simplifies the common pattern of handling
  /// loading, data, and error states with consistent error UI.
  ///
  /// Parameters:
  /// - [data]: Builder for successful data state
  /// - [loading]: Builder for loading state
  /// - [errorHandler]: ErrorHandlerService for processing errors
  /// - [error]: Optional custom error widget builder
  /// - [onRetry]: Callback when user taps retry (enables retry button)
  Widget buildWithErrorHandling({
    required Widget Function(T data) data,
    required Widget Function() loading,
    required ErrorHandlerService errorHandler,
    Widget Function(ErrorResult error)? error,
    VoidCallback? onRetry,
  }) {
    return when(
      data: data,
      loading: loading,
      error: (err, stack) {
        final result = errorHandler.handleError(err, stack);

        // Use custom error builder if provided
        if (error != null) {
          return error(result);
        }

        // Default error widget with optional retry
        return NovaErrorWidget(
          result: result,
          onRetry: result.canRetry ? onRetry : null,
        );
      },
    );
  }

  /// Build widget with error handling and skip loading on refresh
  ///
  /// Similar to [buildWithErrorHandling] but uses [when] with
  /// skipLoadingOnRefresh for smoother refresh experiences.
  Widget buildWithErrorHandlingRefresh({
    required Widget Function(T data) data,
    required Widget Function() loading,
    required ErrorHandlerService errorHandler,
    Widget Function(ErrorResult error)? error,
    VoidCallback? onRetry,
    bool skipLoadingOnRefresh = true,
  }) {
    return when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      data: data,
      loading: loading,
      error: (err, stack) {
        final result = errorHandler.handleError(err, stack);

        if (error != null) {
          return error(result);
        }

        return NovaErrorWidget(
          result: result,
          onRetry: result.canRetry ? onRetry : null,
        );
      },
    );
  }
}

/// Default error widget for Nova app
///
/// Displays error message with appropriate icon based on severity
/// and optional retry button.
class NovaErrorWidget extends StatelessWidget {
  final ErrorResult result;
  final VoidCallback? onRetry;
  final bool compact;

  const NovaErrorWidget({
    super.key,
    required this.result,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForSeverity(result.severity),
              size: 48,
              color: _colorForSeverity(result.severity, isDark),
            ),
            SizedBox(height: NovaSpacing.l),
            Text(
              result.userMessage,
              textAlign: TextAlign.center,
              style: NovaTypography.bodyLarge,
            ),
            if (onRetry != null) ...[
              SizedBox(height: NovaSpacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(result.actionLabel ?? 'Riprova'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? NovaColors.primaryDark : NovaColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(NovaSpacing.m),
      child: Row(
        children: [
          Icon(
            _iconForSeverity(result.severity),
            size: 20,
            color: _colorForSeverity(result.severity, isDark),
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              result.userMessage,
              style: NovaTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(width: NovaSpacing.s),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForSeverity(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.low => Icons.info_outline,
      ErrorSeverity.medium => Icons.warning_amber_rounded,
      ErrorSeverity.high => Icons.error_outline,
      ErrorSeverity.fatal => Icons.dangerous_outlined,
    };
  }

  Color _colorForSeverity(ErrorSeverity severity, bool isDark) {
    return switch (severity) {
      ErrorSeverity.low =>
        isDark ? NovaColors.primaryDark : NovaColors.primaryLight,
      ErrorSeverity.medium => Colors.orange,
      ErrorSeverity.high =>
        isDark ? NovaColors.errorDark : NovaColors.errorLight,
      ErrorSeverity.fatal => Colors.red.shade900,
    };
  }
}

/// Inline error banner for showing errors within existing UI
///
/// Use this for non-blocking errors that should appear within
/// a screen rather than replacing it entirely.
class NovaErrorBanner extends StatelessWidget {
  final ErrorResult result;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const NovaErrorBanner({
    super.key,
    required this.result,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.all(NovaSpacing.m),
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: _backgroundColorForSeverity(result.severity, isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _borderColorForSeverity(result.severity, isDark),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _iconForSeverity(result.severity),
            size: 20,
            color: _iconColorForSeverity(result.severity, isDark),
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              result.userMessage,
              style: NovaTypography.bodySmall,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(result.actionLabel ?? 'Riprova'),
            ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  IconData _iconForSeverity(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.low => Icons.info_outline,
      ErrorSeverity.medium => Icons.warning_amber_rounded,
      ErrorSeverity.high => Icons.error_outline,
      ErrorSeverity.fatal => Icons.dangerous_outlined,
    };
  }

  Color _backgroundColorForSeverity(ErrorSeverity severity, bool isDark) {
    final baseColor = switch (severity) {
      ErrorSeverity.low => Colors.blue,
      ErrorSeverity.medium => Colors.orange,
      ErrorSeverity.high => Colors.red,
      ErrorSeverity.fatal => Colors.red.shade900,
    };
    return baseColor.withValues(alpha: isDark ? 0.2 : 0.1);
  }

  Color _borderColorForSeverity(ErrorSeverity severity, bool isDark) {
    return switch (severity) {
      ErrorSeverity.low => Colors.blue.withValues(alpha: 0.3),
      ErrorSeverity.medium => Colors.orange.withValues(alpha: 0.3),
      ErrorSeverity.high => Colors.red.withValues(alpha: 0.3),
      ErrorSeverity.fatal => Colors.red.shade900.withValues(alpha: 0.3),
    };
  }

  Color _iconColorForSeverity(ErrorSeverity severity, bool isDark) {
    return switch (severity) {
      ErrorSeverity.low => Colors.blue,
      ErrorSeverity.medium => Colors.orange,
      ErrorSeverity.high => Colors.red,
      ErrorSeverity.fatal => Colors.red.shade900,
    };
  }
}
