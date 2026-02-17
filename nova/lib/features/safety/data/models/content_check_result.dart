import 'package:flutter/foundation.dart';

/// Severity levels for content filtering
enum ContentSeverity {
  warning('warning'),
  block('block');

  const ContentSeverity(this.value);
  final String value;

  static ContentSeverity? fromString(String? value) {
    if (value == null) return null;
    return ContentSeverity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ContentSeverity.warning,
    );
  }
}

/// Result of content check against banned words
@immutable
class ContentCheckResult {
  const ContentCheckResult({
    required this.allowed,
    required this.blocked,
    required this.matchedWords,
    this.severity,
  });

  /// Whether the content is allowed (true if clean or only warnings)
  final bool allowed;

  /// Whether the content is blocked (contains blocked words)
  final bool blocked;

  /// List of matched banned words
  final List<String> matchedWords;

  /// Highest severity level of matched words
  final ContentSeverity? severity;

  /// Whether the content is completely clean (no matches)
  bool get isClean => allowed && !blocked && matchedWords.isEmpty;

  /// Whether the content has warnings but is allowed
  bool get hasWarnings => severity == ContentSeverity.warning && !blocked;

  /// Create from Supabase RPC response
  factory ContentCheckResult.fromJson(Map<String, dynamic> json) {
    final matchedWords = json['matched_words'] as List<dynamic>?;
    return ContentCheckResult(
      allowed: json['allowed'] as bool? ?? true,
      blocked: json['blocked'] as bool? ?? false,
      matchedWords: matchedWords?.cast<String>() ?? [],
      severity: ContentSeverity.fromString(json['severity'] as String?),
    );
  }

  /// Create a clean result (no issues)
  factory ContentCheckResult.clean() {
    return const ContentCheckResult(
      allowed: true,
      blocked: false,
      matchedWords: [],
      severity: null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentCheckResult &&
        other.allowed == allowed &&
        other.blocked == blocked &&
        listEquals(other.matchedWords, matchedWords);
  }

  @override
  int get hashCode => Object.hash(allowed, blocked, matchedWords);
}
