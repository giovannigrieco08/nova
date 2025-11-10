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
/// Handles two types of deep links:
/// 1. Event detail: nova://events/{event_id}
/// 2. (Future) Profile: nova://profile/{user_id}
class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();

  /// Stream of incoming deep links (for warm start)
  Stream<DeepLinkInfo> get linkStream => _appLinks.uriLinkStream
      .map((uri) => _parseDeepLink(uri))
      .where((info) => info != null)
      .cast<DeepLinkInfo>();

  /// Get initial deep link if app was opened via deep link (cold start)
  ///
  /// Returns null if app was not opened via deep link.
  Future<DeepLinkInfo?> getInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return null;
      return _parseDeepLink(uri);
    } catch (e) {
      return null;
    }
  }

  /// Parse deep link URI into structured info
  ///
  /// Supported formats:
  /// - nova://events/{event_id}
  /// - nova://profile/{user_id} (future)
  DeepLinkInfo? _parseDeepLink(Uri uri) {
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

  /// Parse event deep link: nova://events/{event_id}
  DeepLinkInfo? _parseEventLink(List<String> pathSegments) {
    if (pathSegments.length < 2) return null;

    final eventId = pathSegments[1];

    // Validate UUID format (basic check)
    if (!_isValidUuid(eventId)) return null;

    return DeepLinkInfo(
      type: DeepLinkType.event,
      eventId: eventId,
    );
  }

  /// Parse profile deep link: nova://profile/{user_id} (future feature)
  DeepLinkInfo? _parseProfileLink(List<String> pathSegments) {
    if (pathSegments.length < 2) return null;

    final userId = pathSegments[1];

    // Validate UUID format (basic check)
    if (!_isValidUuid(userId)) return null;

    return DeepLinkInfo(
      type: DeepLinkType.profile,
      userId: userId,
    );
  }

  /// Basic UUID validation (matches pattern: 8-4-4-4-12 hex digits)
  bool _isValidUuid(String uuid) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(uuid);
  }
}

/// Deep link types supported by Nova
enum DeepLinkType {
  /// Event detail page: nova://events/{event_id}
  event,

  /// Profile page: nova://profile/{user_id} (future)
  profile,
}

/// Parsed deep link information
class DeepLinkInfo {
  final DeepLinkType type;
  final String? eventId;
  final String? userId;

  DeepLinkInfo({
    required this.type,
    this.eventId,
    this.userId,
  });

  @override
  String toString() {
    switch (type) {
      case DeepLinkType.event:
        return 'DeepLinkInfo(event: $eventId)';
      case DeepLinkType.profile:
        return 'DeepLinkInfo(profile: $userId)';
    }
  }
}
