/// Metadata for ephemeral media attached to chat messages.
///
/// Media is stored in Supabase Storage and can be viewed a limited number
/// of times (1 or 2, configurable by sender).
/// Screenshot protection applied on viewing (FLAG_SECURE on Android,
/// detection + notification on iOS).
class ChatMediaInfo {
  final String id;
  final String messageId;
  final String uploaderUserId;
  final String storagePath;
  final ChatMediaType mediaType;
  final int fileSizeBytes;
  final int maxViews; // Maximum views allowed (1 or 2)
  final int viewCount; // Current view count
  final DateTime? viewedAt;
  final String? viewedByUserId;
  final bool screenshotDetected;
  final DateTime expiresAt;
  final DateTime createdAt;
  final int? durationSeconds; // Duration in seconds for audio messages

  const ChatMediaInfo({
    required this.id,
    required this.messageId,
    required this.uploaderUserId,
    required this.storagePath,
    required this.mediaType,
    required this.fileSizeBytes,
    this.maxViews = 1,
    this.viewCount = 0,
    this.viewedAt,
    this.viewedByUserId,
    required this.screenshotDetected,
    required this.expiresAt,
    required this.createdAt,
    this.durationSeconds,
  });

  /// Whether the media has been fully viewed (all views used)
  bool get isViewed => viewCount >= maxViews;

  /// Remaining views available
  int get remainingViews => (maxViews - viewCount).clamp(0, maxViews);

  /// Whether the media has expired (24h from creation)
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether the media can still be viewed
  bool get canView => !isViewed && !isExpired;

  /// Human-readable file size
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else {
      final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    }
  }

  /// Time remaining before expiration
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  /// Duration as Duration object (for audio messages)
  Duration? get duration =>
      durationSeconds != null ? Duration(seconds: durationSeconds!) : null;

  /// Formatted duration string (mm:ss) for audio messages
  String get durationFormatted {
    if (durationSeconds == null) return '00:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMediaInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Type of media attached to a chat message
enum ChatMediaType {
  image('image'),
  video('video'),
  audio('audio');

  /// Database value
  final String value;

  const ChatMediaType(this.value);

  static ChatMediaType fromValue(String value) {
    return values.firstWhere(
      (t) => t.value == value,
      orElse: () => ChatMediaType.image,
    );
  }

  /// Whether this is an image type
  bool get isImage => this == ChatMediaType.image;

  /// Whether this is a video type
  bool get isVideo => this == ChatMediaType.video;

  /// Whether this is an audio type (voice message)
  bool get isAudio => this == ChatMediaType.audio;
}
