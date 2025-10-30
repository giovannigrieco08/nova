// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';

class AppTheme {
  // Prevent instantiation
  AppTheme._();

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,

      // Colors
      primaryColor: NovaColors.primaryLight,
      scaffoldBackgroundColor: NovaColors.backgroundLight,

      // Text theme
      textTheme: TextTheme(
        displayLarge: NovaTextStyles.display,
        headlineLarge: NovaTextStyles.h1,
        headlineMedium: NovaTextStyles.h2,
        headlineSmall: NovaTextStyles.h3,
        bodyLarge: NovaTextStyles.bodyLarge,
        bodyMedium: NovaTextStyles.body,
        bodySmall: NovaTextStyles.caption,
        labelLarge: NovaTextStyles.button,
        labelSmall: NovaTextStyles.overline,
      ),

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
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,

      // Colors
      primaryColor: NovaColors.primaryDark,
      scaffoldBackgroundColor: NovaColors.backgroundDark,

      // Text theme
      textTheme: TextTheme(
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
      ),

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
    );
  }
}
