// Core Utility: DeepLinkHandler
// Feature: 004-event-creation-moderation (US4 - Event Sharing)
// Purpose: Parse and handle deep links for event sharing
//
// Deep Link Format: nova://events/{event_id}
// Example: nova://events/123e4567-e89b-12d3-a456-426614174000
//
// Usage:
// - Cold start: getInitialLink() to check if app was opened via deep link
// - Warm start: linkStream to listen for incoming deep links while app is running

import 'dart:async';
import 'package:app_links/app_links.dart';

/// Deep link handler for Nova app
///
/// Handles deep links:
/// 1. Event detail: nova://events/{event_id}
/// 2. Event comment: nova://events/{event_id}/comments/{comment_id}
/// 3. Profile: nova://profile/{user_id}
///
/// **T126**: Extended to support comment deep links for notifications
class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();

  /// Stream of incoming deep links (for warm start)
  Stream<DeepLinkInfo> get linkStream => _appLinks.uriLinkStream
      .map((uri) => parse(uri))
      .where((info) => info != null)
      .cast<DeepLinkInfo>();

  /// Get initial deep link if app was opened via deep link (cold start)
  ///
  /// Returns null if app was not opened via deep link.
  Future<DeepLinkInfo?> getInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return null;
      return parse(uri);
    } catch (e) {
      return null;
    }
  }

  /// Parse deep link URI into structured info
  ///
  /// Supported formats:
  /// - nova://events/{event_id}
  /// - nova://events/{event_id}/comments/{comment_id}
  /// - nova://profile/{user_id}
  ///
  /// Returns null if URI format is invalid or unsupported.
  DeepLinkInfo? parse(Uri uri) {
    // Check scheme (must be "nova")
    if (uri.scheme != 'nova') return null;

    // Parse path segments
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return null;

    final type = pathSegments[0];

    switch (type) {
      case 'events':
        return _parseEventLink(pathSegments);

      case 'profile':
        return _parseProfileLink(pathSegments);

      default:
        return null;
    }
  }

  /// Parse event deep link:
  /// - nova://events/{event_id}
  /// - nova://events/{event_id}/comments/{comment_id}
  DeepLinkInfo? _parseEventLink(List<String> pathSegments) {
    if (pathSegments.length < 2) return null;

    final eventId = pathSegments[1];

    // Validate UUID format (basic check)
    if (!_isValidUuid(eventId)) return null;

    // Check if this is a comment deep link: nova://events/{event_id}/comments/{comment_id}
    if (pathSegments.length >= 4 && pathSegments[2] == 'comments') {
      final commentId = pathSegments[3];

      // Validate comment UUID format
      if (!_isValidUuid(commentId)) return null;

      return DeepLinkInfo(
        type: DeepLinkType.eventComment,
        eventId: eventId,
        commentId: commentId,
      );
    }

    // Simple event link: nova://events/{event_id}
    return DeepLinkInfo(
      type: DeepLinkType.event,
      eventId: eventId,
    );
  }

  /// Parse profile deep link: nova://profile/{user_id_or_username}
  /// Supports both UUID format and username format (nome.cognome)
  DeepLinkInfo? _parseProfileLink(List<String> pathSegments) {
    if (pathSegments.length < 2) return null;

    final userIdOrUsername = pathSegments[1];

    // Accept both UUID format and username format
    // UUID: 8-4-4-4-12 hex digits
    // Username: lowercase alphanumeric with dots/hyphens (e.g., giovanni.grieco)
    if (!_isValidUuid(userIdOrUsername) && !_isValidUsername(userIdOrUsername)) {
      return null;
    }

    return DeepLinkInfo(
      type: DeepLinkType.profile,
      userId: userIdOrUsername,
    );
  }

  /// Basic UUID validation (matches pattern: 8-4-4-4-12 hex digits)
  bool _isValidUuid(String uuid) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(uuid);
  }

  /// Username validation (lowercase alphanumeric with dots/hyphens)
  /// Examples: giovanni.grieco, marco.rossi2, a.b.c
  /// Min length: 3 characters
  bool _isValidUsername(String username) {
    // Username format: lowercase letters, numbers, dots, hyphens
    // Minimum 3 characters (per database schema)
    // Cannot start/end with dot or hyphen
    final usernamePattern = RegExp(
      r'^[a-z0-9][a-z0-9.-]{1,}[a-z0-9]$',
    );
    return username.length >= 3 && usernamePattern.hasMatch(username);
  }
}

/// Deep link types supported by Nova
enum DeepLinkType {
  /// Event detail page: nova://events/{event_id}
  event,

  /// Event comment page: nova://events/{event_id}/comments/{comment_id}
  /// Opens event detail, then CommentsSheet, scrolls to specific comment
  eventComment,

  /// Profile page: nova://profile/{user_id}
  profile,
}

/// Parsed deep link information
class DeepLinkInfo {
  final DeepLinkType type;
  final String? eventId;
  final String? commentId;
  final String? userId;

  DeepLinkInfo({
    required this.type,
    this.eventId,
    this.commentId,
    this.userId,
  });

  /// Check if this deep link should open comments sheet
  bool get shouldOpenComments => type == DeepLinkType.eventComment;

  /// Check if this deep link should scroll to a specific comment
  bool get hasTargetComment => commentId != null;

  @override
  String toString() {
    switch (type) {
      case DeepLinkType.event:
        return 'DeepLinkInfo(event: $eventId)';
      case DeepLinkType.eventComment:
        return 'DeepLinkInfo(event: $eventId, comment: $commentId)';
      case DeepLinkType.profile:
        return 'DeepLinkInfo(profile: $userId)';
    }
  }
}
