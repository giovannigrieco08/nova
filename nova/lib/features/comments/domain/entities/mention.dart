/// Mention Entity
///
/// Represents an @mention in comment text.
///
/// **T111**: @mention detection and parsing
///
/// Examples:
/// - "@Marco" → Mention(username: "Marco", start: 0, end: 6)
/// - "@Anna_R" → Mention(username: "Anna_R", start: 0, end: 7)
class Mention {
  final String username;
  final int start;
  final int end;
  final String? userId; // Resolved after lookup

  const Mention({
    required this.username,
    required this.start,
    required this.end,
    this.userId,
  });

  /// The full mention text including @
  String get fullText => '@$username';

  /// Length of the mention text
  int get length => end - start;

  Mention copyWith({
    String? username,
    int? start,
    int? end,
    String? userId,
  }) {
    return Mention(
      username: username ?? this.username,
      start: start ?? this.start,
      end: end ?? this.end,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mention &&
        other.username == username &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(username, start, end);

  @override
  String toString() => 'Mention(@$username, $start-$end)';
}

/// Parses @mentions from comment text
///
/// **T111**: @mention detection and parsing
///
/// Pattern: @followed by username (letters, numbers, underscores)
/// - Must be at start of text or preceded by whitespace
/// - Username: 2-30 chars, alphanumeric + underscore
/// - Ends at whitespace or punctuation
///
/// Examples:
/// - "Ciao @Marco come va?" → [Mention(username: "Marco", ...)]
/// - "@Anna Sì! @Luca anche" → [Mention(username: "Anna", ...), Mention(username: "Luca", ...)]
List<Mention> parseMentions(String text) {
  if (text.isEmpty) return [];

  // Pattern: @ followed by alphanumeric/underscore (2-30 chars)
  // Must be preceded by start of string or whitespace
  final pattern = RegExp(r'(?:^|\s)@([a-zA-Z0-9_]{2,30})(?=\s|[,.!?]|$)');

  final mentions = <Mention>[];

  for (final match in pattern.allMatches(text)) {
    // Group 1 is the username without @
    final username = match.group(1)!;

    // Find the actual @ position (group 0 includes optional leading space)
    final matchText = match.group(0)!;
    final atOffset = matchText.indexOf('@');
    final start = match.start + atOffset;
    final end = start + username.length + 1; // +1 for @

    mentions.add(Mention(
      username: username,
      start: start,
      end: end,
    ));
  }

  return mentions;
}

/// Checks if text contains any @mentions
bool hasMentions(String text) {
  return parseMentions(text).isNotEmpty;
}
