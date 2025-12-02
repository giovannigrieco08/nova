import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/mention.dart';

/// MentionText Widget
///
/// Renders comment text with tappable @mentions.
///
/// **T112**: Render @mentions as tappable RichText with purple highlight
/// **T113**: Tap handler for @mentions with profile navigation
/// **T115**: Support multiple mentions in one comment
///
/// Features:
/// - Auto-detects @mentions in text
/// - Renders mentions with Nova brand purple color
/// - Makes mentions tappable with gesture recognizers
/// - Passes username to onMentionTap callback
///
/// Usage:
/// ```dart
/// MentionText(
///   text: "Ciao @Marco! Come va?",
///   onMentionTap: (username) => navigateToProfile(username),
/// )
/// ```
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final ValueChanged<String>? onMentionTap;
  final int? maxLines;
  final TextOverflow? overflow;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.onMentionTap,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final mentions = parseMentions(text);

    // No mentions - return simple text
    if (mentions.isEmpty) {
      return Text(
        text,
        style: style ?? NovaTextStyles.body,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Build text spans with tappable mentions
    final spans = _buildTextSpans(mentions);

    return RichText(
      text: TextSpan(
        style: style ?? NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
        children: spans,
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  /// Builds list of TextSpans with mention highlights
  ///
  /// **T115**: Handles multiple mentions in one comment
  List<TextSpan> _buildTextSpans(List<Mention> mentions) {
    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final mention in mentions) {
      // Add text before this mention
      if (mention.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, mention.start),
        ));
      }

      // Add the mention with highlight and tap handler
      spans.add(TextSpan(
        text: mention.fullText,
        style: TextStyle(
          color: NovaColors.primaryLight,
          fontWeight: FontWeight.w600,
        ),
        recognizer: onMentionTap != null
            ? (TapGestureRecognizer()
              ..onTap = () => onMentionTap!(mention.username))
            : null,
      ));

      currentIndex = mention.end;
    }

    // Add remaining text after last mention
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
    }

    return spans;
  }
}

/// Simple mention highlight without tap handling
///
/// For read-only display of mentions (e.g., in previews)
class MentionHighlightText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const MentionHighlightText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return MentionText(
      text: text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      onMentionTap: null, // No tap handling
    );
  }
}
