// lib/core/theme/nova_colors.dart

import 'package:flutter/material.dart';

/// Nova color palette with context-aware light/dark mode support
///
/// All colors in Nova MUST use these constants to ensure:
/// - Automatic light/dark mode switching
/// - WCAG 2.1 AA accessibility compliance
/// - Visual consistency across the app
///
/// Never hardcode Color(0xFF...) values - always use NovaColors.
class NovaColors {
  // Prevent instantiation
  NovaColors._();

  // ============================================
  // LIGHT MODE COLORS
  // ============================================

  /// Pure white - main background
  static const Color backgroundLight = Color(0xFFFFFFFF);

  /// Slight gray - secondary surfaces (app bar, bottom nav)
  static const Color surfaceLight = Color(0xFFF9FAFB);

  /// White - cards, modals
  static const Color cardLight = Color(0xFFFFFFFF);

  /// Near black - primary text
  static const Color textPrimaryLight = Color(0xFF111827);

  /// Medium gray - secondary text, metadata
  static const Color textSecondaryLight = Color(0xFF6B7280);

  /// Light gray - tertiary text, captions, placeholders
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  /// Vibrant purple - primary actions, CTAs
  static const Color primaryLight = Color(0xFF8B5CF6);

  /// Darker purple - pressed state
  static const Color primaryHoverLight = Color(0xFF7C3AED);

  /// Light gray - borders, outlines
  static const Color borderLight = Color(0xFFE5E7EB);

  /// Very light gray - dividers, separators
  static const Color dividerLight = Color(0xFFF3F4F6);

  /// Red - errors, destructive actions
  static const Color errorLight = Color(0xFFEF4444);

  /// Green - success states
  static const Color successLight = Color(0xFF10B981);

  /// Amber - warnings
  static const Color warningLight = Color(0xFFF59E0B);

  /// Blue - informational messages
  static const Color infoLight = Color(0xFF3B82F6);

  /// Light gray - received message bubbles in chat
  static const Color receivedBubbleLight = Color(0xFFE5E7EB);

  // ============================================
  // DARK MODE COLORS
  // ============================================

  /// Pure black - main background (OLED optimized)
  static const Color backgroundDark = Color(0xFF000000);

  /// Near black - secondary surfaces
  static const Color surfaceDark = Color(0xFF0A0A0A);

  /// Dark gray - cards, modals
  static const Color cardDark = Color(0xFF1A1A1A);

  /// Off-white - primary text
  static const Color textPrimaryDark = Color(0xFFF9FAFB);

  /// Medium gray - secondary text
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  /// Darker gray - tertiary text
  static const Color textTertiaryDark = Color(0xFF6B7280);

  /// Lighter purple - primary actions (better contrast on dark)
  static const Color primaryDark = Color(0xFFA78BFA);

  /// Medium purple - pressed state
  static const Color primaryHoverDark = Color(0xFF8B5CF6);

  /// Dark gray - borders
  static const Color borderDark = Color(0xFF1F2937);

  /// Darker gray - dividers
  static const Color dividerDark = Color(0xFF111827);

  /// Lighter red - better contrast
  static const Color errorDark = Color(0xFFF87171);

  /// Lighter green
  static const Color successDark = Color(0xFF34D399);

  /// Lighter amber
  static const Color warningDark = Color(0xFFFBBF24);

  /// Lighter blue
  static const Color infoDark = Color(0xFF60A5FA);

  /// Dark gray - received message bubbles in chat (slightly lighter than card)
  static const Color receivedBubbleDark = Color(0xFF2A2A2A);

  // ============================================
  // ON-COLOR CONTRASTS (text/icons on colored backgrounds)
  // ============================================

  /// White - text/icons on primary color
  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  /// White - text/icons on primary color (dark mode)
  static const Color onPrimaryDark = Color(0xFFFFFFFF);

  /// White - text/icons on error color
  static const Color onErrorLight = Color(0xFFFFFFFF);

  /// White - text/icons on error color (dark mode)
  static const Color onErrorDark = Color(0xFFFFFFFF);

  /// White - text/icons on success color
  static const Color onSuccessLight = Color(0xFFFFFFFF);

  /// White - text/icons on success color (dark mode)
  static const Color onSuccessDark = Color(0xFFFFFFFF);

  /// Black - text/icons on warning color (yellow needs dark text)
  static const Color onWarningLight = Color(0xFF111827);

  /// Black - text/icons on warning color (dark mode)
  static const Color onWarningDark = Color(0xFF111827);

  // ============================================
  // GLASS TINT COLORS (for liquid glass effect)
  // ============================================

  /// White 9% opacity - subtle glass (light mode)
  static const Color glassTintSubtle = Color(0x18FFFFFF);

  /// White 12% opacity - medium glass (light mode)
  static const Color glassTintMedium = Color(0x20FFFFFF);

  /// White 19% opacity - strong glass (light mode)
  static const Color glassTintStrong = Color(0x30FFFFFF);

  /// White 8% opacity - subtle glass (dark mode)
  static const Color glassTintDarkSubtle = Color(0x15FFFFFF);

  /// White 14% opacity - medium glass (dark mode)
  static const Color glassTintDarkMedium = Color(0x25FFFFFF);

  /// White 21% opacity - strong glass (dark mode)
  static const Color glassTintDarkStrong = Color(0x35FFFFFF);

  // ============================================
  // GLASS BORDER COLORS (for liquid glass borders)
  // ============================================

  /// White 15% opacity - subtle border (light mode)
  static const Color glassBorderSubtle = Color(0x25FFFFFF);

  /// White 21% opacity - medium border (light mode)
  static const Color glassBorderMedium = Color(0x35FFFFFF);

  /// White 27% opacity - strong border (light mode)
  static const Color glassBorderStrong = Color(0x45FFFFFF);

  /// White 19% opacity - subtle border (dark mode)
  static const Color glassBorderDarkSubtle = Color(0x30FFFFFF);

  /// White 25% opacity - medium border (dark mode)
  static const Color glassBorderDarkMedium = Color(0x40FFFFFF);

  /// White 31% opacity - strong border (dark mode)
  static const Color glassBorderDarkStrong = Color(0x50FFFFFF);

  // ============================================
  // CONTEXT-AWARE GETTERS (Auto Light/Dark Mode)
  // ============================================

  /// Check if current theme is dark mode
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Background color (context-aware)
  static Color background(BuildContext context) {
    return isDark(context) ? backgroundDark : backgroundLight;
  }

  /// Surface color (context-aware)
  static Color surface(BuildContext context) {
    return isDark(context) ? surfaceDark : surfaceLight;
  }

  /// Card color (context-aware)
  static Color card(BuildContext context) {
    return isDark(context) ? cardDark : cardLight;
  }

  /// Primary text color (context-aware)
  static Color textPrimary(BuildContext context) {
    return isDark(context) ? textPrimaryDark : textPrimaryLight;
  }

  /// Secondary text color (context-aware)
  static Color textSecondary(BuildContext context) {
    return isDark(context) ? textSecondaryDark : textSecondaryLight;
  }

  /// Tertiary text color (context-aware)
  static Color textTertiary(BuildContext context) {
    return isDark(context) ? textTertiaryDark : textTertiaryLight;
  }

  /// Primary color (context-aware)
  static Color primary(BuildContext context) {
    return isDark(context) ? primaryDark : primaryLight;
  }

  /// Primary hover color (context-aware)
  static Color primaryHover(BuildContext context) {
    return isDark(context) ? primaryHoverDark : primaryHoverLight;
  }

  /// Border color (context-aware)
  static Color border(BuildContext context) {
    return isDark(context) ? borderDark : borderLight;
  }

  /// Divider color (context-aware)
  static Color divider(BuildContext context) {
    return isDark(context) ? dividerDark : dividerLight;
  }

  /// Error color (context-aware)
  static Color error(BuildContext context) {
    return isDark(context) ? errorDark : errorLight;
  }

  /// Success color (context-aware)
  static Color success(BuildContext context) {
    return isDark(context) ? successDark : successLight;
  }

  /// Warning color (context-aware)
  static Color warning(BuildContext context) {
    return isDark(context) ? warningDark : warningLight;
  }

  /// Info color (context-aware)
  static Color info(BuildContext context) {
    return isDark(context) ? infoDark : infoLight;
  }

  /// Received message bubble color (context-aware) - for chat message bubbles from others
  static Color receivedBubble(BuildContext context) {
    return isDark(context) ? receivedBubbleDark : receivedBubbleLight;
  }

  /// On-primary color (context-aware) - for text/icons on primary background
  static Color onPrimary(BuildContext context) {
    return isDark(context) ? onPrimaryDark : onPrimaryLight;
  }

  /// On-error color (context-aware) - for text/icons on error background
  static Color onError(BuildContext context) {
    return isDark(context) ? onErrorDark : onErrorLight;
  }

  /// On-success color (context-aware) - for text/icons on success background
  static Color onSuccess(BuildContext context) {
    return isDark(context) ? onSuccessDark : onSuccessLight;
  }

  /// On-warning color (context-aware) - for text/icons on warning background
  static Color onWarning(BuildContext context) {
    return isDark(context) ? onWarningDark : onWarningLight;
  }

  // ============================================
  // BRAND GRADIENT COLORS
  // ============================================

  /// Brand gradient start - purple
  static const Color gradientStart = Color(0xFF833AB4);

  /// Brand gradient end - pink/red
  static const Color gradientEnd = Color(0xFFFD1D1D);

  /// Brand gradient for avatars and accents
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Like active color (Instagram red)
  static const Color likeActive = Color(0xFFED4956);

  // ============================================
  // OVERLAY & TRANSPARENT COLORS
  // ============================================

  /// Transparent color (fully transparent)
  static const Color transparent = Color(0x00000000);

  /// Dark overlay (for modal backgrounds, image overlays)
  static const Color overlayDark = Color(0x99000000);

  /// Light overlay
  static const Color overlayLight = Color(0x40FFFFFF);

  // ============================================
  // SEMANTIC GRAYS (Static)
  // ============================================

  /// Light gray for placeholders and backgrounds
  static const Color grayLight = Color(0xFFF5F5F5);

  /// Medium gray for disabled states
  static const Color grayMedium = Color(0xFFE0E0E0);

  /// Gray for timestamps and metadata
  static const Color grayDark = Color(0xFF737373);

  /// Placeholder background
  static const Color placeholder = Color(0xFFF0F0F0);

  /// Handle bar color for sheets
  static const Color handleBar = Color(0xFFD0D0D0);

  // ============================================
  // HELP REQUEST COLORS
  // ============================================

  /// Help request background (light orange)
  static const Color helpBackground = Color(0xFFFFF3E0);

  /// Help request border (orange)
  static const Color helpBorder = Color(0xFFFFB74D);

  /// Help request accent (orange)
  static const Color helpAccent = Color(0xFFFF9800);

  /// Help request text (dark orange)
  static const Color helpText = Color(0xFFE65100);

  // ============================================
  // EVENT STATUS COLORS
  // ============================================

  /// Event pending status background (light yellow)
  static const Color eventPendingBackground = Color(0xFFFFF3CD);

  /// Event pending status text (dark yellow/brown)
  static const Color eventPendingText = Color(0xFF856404);

  /// Event approved status background (light green)
  static const Color eventApprovedBackground = Color(0xFFD4EDDA);

  /// Event approved status text (dark green)
  static const Color eventApprovedText = Color(0xFF155724);

  /// Event rejected status background (light red)
  static const Color eventRejectedBackground = Color(0xFFF8D7DA);

  /// Event rejected status text (dark red)
  static const Color eventRejectedText = Color(0xFF721C24);

  // ============================================
  // AVATAR COLORS (Material Design 500 palette)
  // ============================================

  /// Material Design 500 color palette for avatar backgrounds (17 colors)
  /// Used by AvatarInitialsGenerator for deterministic name-based coloring
  static const List<Color> avatarColors = [
    Color(0xFFF44336), // Red 500
    Color(0xFFE91E63), // Pink 500
    Color(0xFF9C27B0), // Purple 500
    Color(0xFF673AB7), // Deep Purple 500
    Color(0xFF3F51B5), // Indigo 500
    Color(0xFF2196F3), // Blue 500
    Color(0xFF03A9F4), // Light Blue 500
    Color(0xFF00BCD4), // Cyan 500
    Color(0xFF009688), // Teal 500
    Color(0xFF4CAF50), // Green 500
    Color(0xFF8BC34A), // Light Green 500
    Color(0xFFCDDC39), // Lime 500
    Color(0xFFFFC107), // Amber 500
    Color(0xFFFF9800), // Orange 500
    Color(0xFFFF5722), // Deep Orange 500
    Color(0xFF795548), // Brown 500
    Color(0xFF607D8B), // Blue Grey 500
  ];

  /// Avatar quick access colors (subset for small color pickers)
  static const List<Color> avatarColorsQuick = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF59E0B), // Amber
  ];

  // ============================================
  // SOCIAL MEDIA & BRAND COLORS
  // ============================================

  /// WhatsApp brand green - for WhatsApp contact buttons
  static const Color whatsappGreen = Color(0xFF25D366);

  /// Instagram brand pink - for Instagram contact buttons
  static const Color instagramPink = Color(0xFFE4405F);

  /// Material Green 500 - for approve/success action buttons
  static const Color approveGreen = Color(0xFF4CAF50);

  // ============================================
  // MEDIA & EDITOR COLORS
  // ============================================

  /// Photo editor dark background
  static const Color editorBackground = Color(0xFF121212);

  // ============================================
  // LEGACY ALIASES (backward compatibility)
  // ============================================

  /// @deprecated Use [gradientStart] or [primary] instead
  static const Color brandViolet = primaryLight;

  /// @deprecated Use [gradientEnd] instead
  static const Color brandPink = Color(0xFFEC4899); // Pink-500

  /// @deprecated Use [likeActive] instead
  static const Color instagramRed = Color(0xFFE1306C); // Instagram brand red

  /// @deprecated Use [background] instead
  static Color backgroundPrimary(BuildContext context) => background(context);

  /// @deprecated Use [surface] instead
  static Color backgroundSecondary(BuildContext context) => surface(context);

  /// @deprecated Use [card] instead
  static Color backgroundTertiary(BuildContext context) => card(context);

  /// @deprecated Use [border] instead
  static Color borderPrimary(BuildContext context) => border(context);

  // ============================================
  // STATIC COLORS (No BuildContext Required)
  // Use these when BuildContext is not available
  // (e.g., in animations, builders outside widget tree)
  // ============================================

  /// Primary color - static light mode version
  static const Color primaryStatic = primaryLight;

  /// Error color - static light mode version
  static const Color errorStatic = errorLight;

  /// Warning color - static light mode version
  static const Color warningStatic = warningLight;

  /// Success color - static light mode version
  static const Color successStatic = successLight;

  /// Info color - static light mode version
  static const Color infoStatic = infoLight;

  /// Primary text - static light mode version
  static const Color textPrimaryStatic = textPrimaryLight;

  /// Secondary text - static light mode version
  static const Color textSecondaryStatic = textSecondaryLight;

  /// Tertiary text - static light mode version
  static const Color textTertiaryStatic = textTertiaryLight;

  /// Background - static light mode version
  static const Color backgroundStatic = backgroundLight;

  /// Surface - static light mode version
  static const Color surfaceStatic = surfaceLight;

  /// Card - static light mode version
  static const Color cardStatic = cardLight;

  /// Border - static light mode version
  static const Color borderStatic = borderLight;
}
