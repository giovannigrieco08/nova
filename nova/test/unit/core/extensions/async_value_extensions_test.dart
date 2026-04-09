/// Tests for AsyncValue error handling extensions
///
/// Tests handleError and buildWithErrorHandling on AsyncValue states.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/extensions/async_value_extensions.dart';
import 'package:nova/core/services/error_handler_service.dart';
import 'package:nova/core/exceptions/nova_exceptions.dart';

void main() {
  group('AsyncValueErrorHandling', () {
    late ErrorHandlerService errorHandler;

    setUp(() {
      errorHandler = ErrorHandlerService(isProduction: false);
    });

    // =========================================================================
    // handleError
    // =========================================================================

    group('handleError', () {
      test('returns ErrorResult for error state (happy)', () {
        const asyncValue = AsyncValue<String>.error(
          NetworkException('Connection lost'),
          StackTrace.empty,
        );

        final result = asyncValue.handleError(errorHandler);

        expect(result, isNotNull);
        expect(result!.userMessage, equals('Connection lost'));
        expect(result.severity, equals(ErrorSeverity.medium));
      });

      test('returns null for data state (happy)', () {
        const asyncValue = AsyncValue<String>.data('hello');

        final result = asyncValue.handleError(errorHandler);

        expect(result, isNull);
      });

      test('returns null for loading state (happy)', () {
        const asyncValue = AsyncValue<String>.loading();

        final result = asyncValue.handleError(errorHandler);

        expect(result, isNull);
      });

      test('handles generic exception in error state (happy)', () {
        final asyncValue = AsyncValue<String>.error(
          Exception('generic error'),
          StackTrace.empty,
        );

        final result = asyncValue.handleError(errorHandler);

        expect(result, isNotNull);
        expect(result!.exception, isA<ServerException>());
      });
    });

    // =========================================================================
    // buildWithErrorHandling
    // =========================================================================

    group('buildWithErrorHandling', () {
      testWidgets('renders data widget for data state (happy)',
          (tester) async {
        const asyncValue = AsyncValue<String>.data('test data');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandling(
                data: (data) => Text(data),
                loading: () => const CircularProgressIndicator(),
                errorHandler: errorHandler,
              ),
            ),
          ),
        );

        expect(find.text('test data'), findsOneWidget);
      });

      testWidgets('renders loading widget for loading state (happy)',
          (tester) async {
        const asyncValue = AsyncValue<String>.loading();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandling(
                data: (data) => Text(data),
                loading: () => const Text('Loading...'),
                errorHandler: errorHandler,
              ),
            ),
          ),
        );

        expect(find.text('Loading...'), findsOneWidget);
      });

      testWidgets('renders default error widget for error state (happy)',
          (tester) async {
        const asyncValue = AsyncValue<String>.error(
          NetworkException('Network down'),
          StackTrace.empty,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandling(
                data: (data) => Text(data),
                loading: () => const CircularProgressIndicator(),
                errorHandler: errorHandler,
              ),
            ),
          ),
        );

        expect(find.text('Network down'), findsOneWidget);
      });

      testWidgets('renders custom error widget when provided (edge)',
          (tester) async {
        const asyncValue = AsyncValue<String>.error(
          ServerException('Server error'),
          StackTrace.empty,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandling(
                data: (data) => Text(data),
                loading: () => const CircularProgressIndicator(),
                errorHandler: errorHandler,
                error: (result) => Text('Custom: ${result.userMessage}'),
              ),
            ),
          ),
        );

        expect(find.text('Custom: Server error'), findsOneWidget);
      });

      testWidgets('shows retry button when canRetry is true (edge)',
          (tester) async {
        const asyncValue = AsyncValue<String>.error(
          NetworkException('Network error'),
          StackTrace.empty,
        );
        var retryCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandling(
                data: (data) => Text(data),
                loading: () => const CircularProgressIndicator(),
                errorHandler: errorHandler,
                onRetry: () => retryCount++,
              ),
            ),
          ),
        );

        // NetworkException has canRetry=true, so retry button should appear
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh));
        expect(retryCount, equals(1));
      });

      testWidgets('does not show retry button when canRetry is false (edge)',
          (tester) async {
        const asyncValue = AsyncValue<String>.error(
          UnauthorizedException('Login required'),
          StackTrace.empty,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandling(
                data: (data) => Text(data),
                loading: () => const CircularProgressIndicator(),
                errorHandler: errorHandler,
                onRetry: () {}, // providing retry callback
              ),
            ),
          ),
        );

        // UnauthorizedException canRetry=false, so no retry icon
        expect(find.byIcon(Icons.refresh), findsNothing);
      });
    });

    // =========================================================================
    // buildWithErrorHandlingRefresh
    // =========================================================================

    group('buildWithErrorHandlingRefresh', () {
      testWidgets('renders data widget (race: refresh handling)', (tester) async {
        const asyncValue = AsyncValue<String>.data('refreshed data');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandlingRefresh(
                data: (data) => Text(data),
                loading: () => const Text('Loading...'),
                errorHandler: errorHandler,
              ),
            ),
          ),
        );

        expect(find.text('refreshed data'), findsOneWidget);
      });

      testWidgets('uses custom skipLoadingOnRefresh (race: loading skip)', (tester) async {
        const asyncValue = AsyncValue<String>.loading();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: asyncValue.buildWithErrorHandlingRefresh(
                data: (data) => Text(data),
                loading: () => const Text('Loading...'),
                errorHandler: errorHandler,
                skipLoadingOnRefresh: false,
              ),
            ),
          ),
        );

        expect(find.text('Loading...'), findsOneWidget);
      });
    });
  });

  // ===========================================================================
  // NovaErrorWidget
  // ===========================================================================

  group('NovaErrorWidget', () {
    testWidgets('compact mode renders inline (happy)', (tester) async {
      const result = ErrorResult(
        userMessage: 'Compact error',
        severity: ErrorSeverity.low,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NovaErrorWidget(result: result, compact: true),
          ),
        ),
      );

      expect(find.text('Compact error'), findsOneWidget);
    });

    testWidgets('full mode centers content (happy)', (tester) async {
      const result = ErrorResult(
        userMessage: 'Full error display',
        severity: ErrorSeverity.high,
        canRetry: true,
        actionLabel: 'Riprova',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaErrorWidget(
              result: result,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Full error display'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
    });
  });

  // ===========================================================================
  // NovaErrorBanner
  // ===========================================================================

  group('NovaErrorBanner', () {
    testWidgets('renders banner with retry and dismiss (happy)', (tester) async {
      const result = ErrorResult(
        userMessage: 'Banner error',
        severity: ErrorSeverity.medium,
        canRetry: true,
        actionLabel: 'Retry',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovaErrorBanner(
              result: result,
              onRetry: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Banner error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
