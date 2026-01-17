// Provider: ThemeModeProvider
// Purpose: Always use light theme (dark/system themes disabled for now)
//
// Usage:
// ```dart
// // In main.dart MaterialApp:
// themeMode: ref.watch(themeModeProvider),
// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for current theme mode - always returns light
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.light;
});
