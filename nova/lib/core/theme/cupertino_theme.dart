import 'package:flutter/cupertino.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Cupertino (iOS) theme configuration.
///
/// Uses same NovaColors and NovaTypography as Material theme
/// to ensure visual consistency across platforms.
class NovaCupertinoTheme {
  // Prevent instantiation
  NovaCupertinoTheme._();

  // Private cache variables for lazy initialization
  static CupertinoThemeData? _cachedLight;
  static CupertinoThemeData? _cachedDark;

  /// Light Cupertino theme (lazy-initialized and cached)
  static CupertinoThemeData get light {
    _cachedLight ??= CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: NovaColors.primaryLight,
      primaryContrastingColor: CupertinoColors.white,
      scaffoldBackgroundColor: NovaColors.backgroundLight,
      barBackgroundColor: NovaColors.surfaceLight,

      // Typography using Inter font (same as Material)
      textTheme: CupertinoTextThemeData(
        textStyle: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
        primaryColor: NovaColors.primaryLight,
        actionTextStyle: NovaTextStyles.button.copyWith(
          color: NovaColors.primaryLight,
        ),
        navTitleTextStyle: NovaTextStyles.h2.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
        navLargeTitleTextStyle: NovaTextStyles.h1.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
        pickerTextStyle: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
        dateTimePickerTextStyle: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
        tabLabelTextStyle: NovaTextStyles.caption.copyWith(
          color: NovaColors.textSecondaryLight,
        ),
      ),
    );
    return _cachedLight!;
  }

  /// Dark Cupertino theme (lazy-initialized and cached)
  static CupertinoThemeData get dark {
    _cachedDark ??= CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: NovaColors.primaryDark,
      primaryContrastingColor: CupertinoColors.black,
      scaffoldBackgroundColor: NovaColors.backgroundDark,
      barBackgroundColor: NovaColors.surfaceDark,

      // Typography using Inter font (same as Material)
      textTheme: CupertinoTextThemeData(
        textStyle: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        primaryColor: NovaColors.primaryDark,
        actionTextStyle: NovaTextStyles.button.copyWith(
          color: NovaColors.primaryDark,
        ),
        navTitleTextStyle: NovaTextStyles.h2.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        navLargeTitleTextStyle: NovaTextStyles.h1.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        pickerTextStyle: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        dateTimePickerTextStyle: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryDark,
        ),
        tabLabelTextStyle: NovaTextStyles.caption.copyWith(
          color: NovaColors.textSecondaryDark,
        ),
      ),
    );
    return _cachedDark!;
  }
}
