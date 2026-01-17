/// Test utilities for Nova app
///
/// Provides helper functions and utilities for writing tests.
/// Import this in your test files along with mocks and fixtures.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget wrapped in necessary providers for testing
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(
///   testableWidget(
///     child: MyWidget(),
///     overrides: [myProvider.overrideWithValue(mockValue)],
///   ),
/// );
/// ```
Widget testableWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      themeMode: ThemeMode.light,
      theme: ThemeData.light(),
      home: Material(child: child),
    ),
  );
}

/// Creates a ProviderContainer with common overrides for testing
///
/// Usage:
/// ```dart
/// final container = createTestContainer(
///   overrides: [myProvider.overrideWithValue(mockValue)],
/// );
/// final result = container.read(myProvider);
/// ```
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
  ProviderContainer? parent,
}) {
  return ProviderContainer(
    overrides: overrides,
    parent: parent,
  );
}

/// Extension to add useful methods to WidgetTester
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps widget and waits for animations to complete
  Future<void> pumpAndSettle2({
    Duration duration = const Duration(milliseconds: 100),
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  }) async {
    await pumpAndSettle(duration, phase);
  }

  /// Pumps widget and waits for specified duration
  Future<void> pumpFor(Duration duration) async {
    await pump(duration);
  }
}

/// Golden test helper - creates consistent golden file names
String goldenFileName(String testName) {
  return 'goldens/${testName.replaceAll(' ', '_').toLowerCase()}.png';
}

/// Matcher for checking if a widget has specific text
Matcher hasText(String text) => find.text(text);

/// Matcher for checking if widget contains a substring
Matcher containsText(String substring) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.contains(substring)) {
        return true;
      }
    }
    return false;
  });
}
