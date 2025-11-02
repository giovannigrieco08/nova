// Core Utility: Avatar Initials Generator
// Feature: 002-profile-setup
// Purpose: Generate colored initials for avatars using Material Design 500 colors

import 'package:flutter/material.dart';

/// Generates initials and deterministic colors for avatar backgrounds
/// Uses Material Design 500 color palette with A-Z mapping
class AvatarInitialsGenerator {
  /// Material Design 500 color palette (17 colors)
  /// Cycle through alphabet: A-Q use colors 0-16, R-Z wrap around
  static const List<Color> materialColors500 = [
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

  /// Extracts initials from full name
  /// Examples:
  /// - "Giovanni Rossi" → "GR"
  /// - "Maria Bianchi" → "MB"
  /// - "Name" → "N"
  /// - "" → "?"
  static String getInitials(String fullName) {
    if (fullName.trim().isEmpty) {
      return '?';
    }

    final parts = fullName.trim().split(' ');

    if (parts.length == 1) {
      // Single word: return first character
      return parts[0][0].toUpperCase();
    } else {
      // Multiple words: return first character of first and last part
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    }
  }

  /// Gets deterministic background color based on first character of name
  /// Same name always returns same color
  /// A→Red, B→Pink, C→Purple, ..., Q→Blue Grey, R→Red (cycles)
  static Color getColor(String fullName) {
    if (fullName.trim().isEmpty) {
      return materialColors500[0]; // Default to Red 500
    }

    final firstChar = fullName.trim()[0].toUpperCase();
    final charCode = firstChar.codeUnitAt(0);

    // Calculate index: A=65, B=66, ..., Z=90
    // Map to 0-16 with modulo (17 colors)
    if (charCode >= 65 && charCode <= 90) {
      // A-Z
      final index = (charCode - 65) % materialColors500.length;
      return materialColors500[index];
    } else {
      // Non-alphabetic first character: default to Red 500
      return materialColors500[0];
    }
  }

  /// Generates both initials and color for convenience
  /// Returns a map with 'initials' (String) and 'color' (Color)
  static Map<String, dynamic> generate(String fullName) {
    return {
      'initials': getInitials(fullName),
      'color': getColor(fullName),
    };
  }

  /// Gets index of color (0-16) for testing/debugging
  static int getColorIndex(String fullName) {
    if (fullName.trim().isEmpty) {
      return 0;
    }

    final firstChar = fullName.trim()[0].toUpperCase();
    final charCode = firstChar.codeUnitAt(0);

    if (charCode >= 65 && charCode <= 90) {
      return (charCode - 65) % materialColors500.length;
    } else {
      return 0;
    }
  }
}
