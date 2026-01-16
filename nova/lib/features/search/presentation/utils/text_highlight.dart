/// Text highlighting utility for search results
///
/// Provides case-insensitive bold highlighting of search terms in text.
library;

import 'package:flutter/material.dart';

/// Creates a TextSpan with highlighted search terms
///
/// Highlights all occurrences of [query] in [text] with bold styling.
/// Case-insensitive matching.
TextSpan highlightText({
  required String text,
  required String query,
  required TextStyle baseStyle,
  TextStyle? highlightStyle,
}) {
  if (query.isEmpty || text.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final effectiveHighlightStyle = highlightStyle ??
      baseStyle.copyWith(
        fontWeight: FontWeight.w700,
      );

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase().trim();

  if (lowerQuery.isEmpty || !lowerText.contains(lowerQuery)) {
    return TextSpan(text: text, style: baseStyle);
  }

  final spans = <TextSpan>[];
  int start = 0;

  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);

    if (index == -1) {
      // No more matches, add remaining text
      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      }
      break;
    }

    // Add text before match
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }

    // Add highlighted match (preserve original case)
    spans.add(TextSpan(
      text: text.substring(index, index + lowerQuery.length),
      style: effectiveHighlightStyle,
    ));

    start = index + lowerQuery.length;
  }

  return TextSpan(children: spans);
}

/// Widget that displays text with highlighted search terms
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: highlightText(
        text: text,
        query: query,
        baseStyle: style,
        highlightStyle: highlightStyle,
      ),
    );
  }
}
