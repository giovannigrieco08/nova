// lib/core/theme/nova_typography.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaTextStyles {
  // Prevent instantiation
  NovaTextStyles._();

  /// Display text style (32px, bold, -0.02em tracking)
  /// Usage: Hero headlines, splash screen titles
  static final TextStyle display = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.64, // -0.02em = -0.64px at 32px
  );

  /// H1 text style (24px, bold, -0.01em tracking)
  /// Usage: Screen titles
  static final TextStyle h1 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.24, // -0.01em = -0.24px at 24px
  );

  /// H2 text style (20px, semibold)
  /// Usage: Section headers
  static final TextStyle h2 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// H3 text style (18px, semibold)
  /// Usage: Subsection headers, card titles
  static final TextStyle h3 = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Body Large text style (16px, regular)
  /// Usage: Emphasized paragraphs
  static final TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body text style (15px, regular) - Instagram size
  /// Usage: Primary body text, descriptions, comments, chat
  static final TextStyle body = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Body Bold text style (15px, semibold)
  /// Usage: Usernames, inline emphasis
  static final TextStyle bodyBold = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Caption text style (13px, regular)
  /// Usage: Timestamps, metadata, secondary labels
  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Small text style (11px, regular)
  /// Usage: Legal text, micro labels (use sparingly)
  static final TextStyle small = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Button text style (15px, semibold, tight line height)
  /// Usage: All buttons and CTAs
  static final TextStyle button = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.0, // Tight for vertical centering
  );

  /// Overline text style (10px, semibold, uppercase, tracked)
  /// Usage: Category labels, badges, eyebrows
  static final TextStyle overline = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5, // 0.05em = 0.5px at 10px
  );
}
