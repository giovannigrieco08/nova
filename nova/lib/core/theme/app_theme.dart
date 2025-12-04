// lib/core/theme/app_theme.dart

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_animations.dart';

class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // Private cache variables for lazy initialization
  static ThemeData? _cachedLightTheme;
  static ThemeData? _cachedDarkTheme;

  /// Check if running on Android (for font selection)
  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false; // Web or other platforms use default
    }
  }

  /// Get text theme with Inter font on Android, system font on iOS
  static TextTheme _getTextTheme(TextTheme baseTheme) {
    if (_isAndroid) {
      return GoogleFonts.interTextTheme(baseTheme);
    }
    return baseTheme; // iOS uses SF Pro system font
  }

  /// Light theme configuration (lazy-initialized and cached)
  static ThemeData get lightTheme {
    _cachedLightTheme ??= ThemeData(
      useMaterial3: true, // Enable Material 3
      brightness: Brightness.light,

      // Material 3 ColorScheme
      colorScheme: ColorScheme.light(
        primary: NovaColors.primaryLight,
        surface: NovaColors.surfaceLight,
        background: NovaColors.backgroundLight,
        error: NovaColors.errorLight,
        onPrimary: Colors.white,
        onSurface: NovaColors.textPrimaryLight,
        onBackground: NovaColors.textPrimaryLight,
        onError: Colors.white,
      ),

      // Colors (legacy, kept for compatibility)
      primaryColor: NovaColors.primaryLight,
      scaffoldBackgroundColor: NovaColors.backgroundLight,

      // Text theme (Inter on Android, SF Pro on iOS)
      textTheme: _getTextTheme(TextTheme(
        displayLarge: NovaTextStyles.display,
        headlineLarge: NovaTextStyles.h1,
        headlineMedium: NovaTextStyles.h2,
        headlineSmall: NovaTextStyles.h3,
        bodyLarge: NovaTextStyles.bodyLarge,
        bodyMedium: NovaTextStyles.body,
        bodySmall: NovaTextStyles.caption,
        labelLarge: NovaTextStyles.button,
        labelSmall: NovaTextStyles.overline,
      )),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: NovaColors.surfaceLight,
        foregroundColor: NovaColors.textPrimaryLight,
        elevation: 0,
        titleTextStyle: NovaTextStyles.h2.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: NovaColors.surfaceLight,
        selectedItemColor: NovaColors.primaryLight,
        unselectedItemColor: NovaColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: NovaColors.cardLight,
        elevation: 0, // We use shadows manually
        shape: RoundedRectangleBorder(
          borderRadius: NovaRadius.circularM,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NovaColors.surfaceLight,
        hintStyle: NovaTextStyles.bodyMedium.copyWith(
          color: NovaColors.textTertiaryLight,
        ),
        border: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
          borderSide: BorderSide(color: NovaColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
          borderSide: BorderSide(color: NovaColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
          borderSide: BorderSide(color: NovaColors.primaryLight, width: 2),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.primaryLight,
          foregroundColor: Colors.white,
          textStyle: NovaTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: NovaRadius.circularS,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.m,
          ),
        ),
      ),

      // Material 3 filled button theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NovaColors.primaryLight,
          foregroundColor: Colors.white,
          textStyle: NovaTextStyles.button,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: NovaRadius.circularL,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.m,
          ),
        ),
      ),

      // Material 3 navigation bar theme (for bottom navigation)
      navigationBarTheme: NavigationBarThemeData(
        height: 60,
        elevation: 0,
        backgroundColor: NovaColors.surfaceLight,
        indicatorColor: NovaColors.primaryLight.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return NovaTextStyles.caption.copyWith(
              color: NovaColors.primaryLight,
              fontWeight: FontWeight.w600,
            );
          }
          return NovaTextStyles.caption.copyWith(
            color: NovaColors.textSecondaryLight,
          );
        }),
      ),

      // Page transitions (platform-adaptive)
      pageTransitionsTheme: NovaAnimations.pageTransitionsTheme,
    );
    return _cachedLightTheme!;
  }

  /// Dark theme configuration (lazy-initialized and cached)
  static ThemeData get darkTheme {
    _cachedDarkTheme ??= ThemeData(
      useMaterial3: true, // Enable Material 3
      brightness: Brightness.dark,

      // Material 3 ColorScheme
      colorScheme: ColorScheme.dark(
        primary: NovaColors.primaryDark,
        surface: NovaColors.surfaceDark,
        background: NovaColors.backgroundDark,
        error: NovaColors.errorDark,
        onPrimary: Colors.white,
        onSurface: NovaColors.textPrimaryDark,
        onBackground: NovaColors.textPrimaryDark,
        onError: Colors.white,
      ),

      // Colors (legacy, kept for compatibility)
      primaryColor: NovaColors.primaryDark,
      scaffoldBackgroundColor: NovaColors.backgroundDark,

      // Text theme (Inter on Android, SF Pro on iOS)
      textTheme: _getTextTheme(TextTheme(
        displayLarge: NovaTextStyles.display.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        headlineLarge: NovaTextStyles.h1.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        headlineMedium: NovaTextStyles.h2.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        headlineSmall: NovaTextStyles.h3.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        bodyLarge: NovaTextStyles.bodyLarge.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        bodyMedium: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        bodySmall: NovaTextStyles.caption.copyWith(
          color: NovaColors.textSecondaryDark,
        ),
        labelLarge: NovaTextStyles.button.copyWith(
          color: Colors.white,
        ),
        labelSmall: NovaTextStyles.overline.copyWith(
          color: NovaColors.textSecondaryDark,
        ),
      )),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: NovaColors.surfaceDark,
        foregroundColor: NovaColors.textPrimaryDark,
        elevation: 0,
        titleTextStyle: NovaTextStyles.h2.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: NovaColors.surfaceDark,
        selectedItemColor: NovaColors.primaryDark,
        unselectedItemColor: NovaColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: NovaColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: NovaRadius.circularM,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NovaColors.surfaceDark,
        hintStyle: NovaTextStyles.bodyMedium.copyWith(
          color: NovaColors.textTertiaryDark,
        ),
        border: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
          borderSide: BorderSide(color: NovaColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
          borderSide: BorderSide(color: NovaColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
          borderSide: BorderSide(color: NovaColors.primaryDark, width: 2),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.primaryDark,
          foregroundColor: Colors.white,
          textStyle: NovaTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: NovaRadius.circularS,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.m,
          ),
        ),
      ),

      // Material 3 filled button theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NovaColors.primaryDark,
          foregroundColor: Colors.white,
          textStyle: NovaTextStyles.button,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: NovaRadius.circularL,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.m,
          ),
        ),
      ),

      // Material 3 navigation bar theme (for bottom navigation)
      navigationBarTheme: NavigationBarThemeData(
        height: 60,
        elevation: 0,
        backgroundColor: NovaColors.surfaceDark,
        indicatorColor: NovaColors.primaryDark.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return NovaTextStyles.caption.copyWith(
              color: NovaColors.primaryDark,
              fontWeight: FontWeight.w600,
            );
          }
          return NovaTextStyles.caption.copyWith(
            color: NovaColors.textSecondaryDark,
          );
        }),
      ),

      // Page transitions (platform-adaptive)
      pageTransitionsTheme: NovaAnimations.pageTransitionsTheme,
    );
    return _cachedDarkTheme!;
  }
}
