// Provider: ThemeModeProvider
// Purpose: Manage app theme mode (system/light/dark) with SharedPreferences persistence
//
// Usage:
// ```dart
// // In main.dart MaterialApp:
// themeMode: ref.watch(themeModeProvider),
//
// // To change theme:
// ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profile/presentation/providers/incomplete_profile_provider.dart'
    show sharedPreferencesProvider;

const _themeModeKey = 'theme_mode';

/// Provider for current theme mode
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

/// Notifier that manages theme mode state and persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  /// Load saved theme mode from SharedPreferences
  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(_themeModeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Set and persist theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_themeModeKey, mode.name);
  }

  /// Get display name for current theme mode (Italian)
  String get displayName {
    switch (state) {
      case ThemeMode.light:
        return 'Chiaro';
      case ThemeMode.dark:
        return 'Scuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }
}

/// Helper to get theme mode display name
String themeModeDisplayName(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Chiaro';
    case ThemeMode.dark:
      return 'Scuro';
    case ThemeMode.system:
      return 'Sistema';
  }
}
