// Core Service: ShareService
// Feature: 004-event-creation-moderation (US4 - Event Sharing)
// Purpose: Share events via native share sheet with deep links
//
// Deep Link Format: nova://events/{event_id}
// Share Message Format:
// "Guarda questo evento su Nova: {event.title}
//  nova://events/{event_id}"
//
// Usage:
// ```dart
// await ShareService.shareEvent(event);
// ```

import 'package:share_plus/share_plus.dart';
import '../../features/events/domain/entities/event.dart';

/// Service for sharing Nova content via native share sheet
class ShareService {
  // Prevent instantiation - static utility class
  ShareService._();

  /// Share event via native share sheet
  ///
  /// Generates deep link and formats share message.
  /// On iOS/Android, this will open the system share sheet.
  ///
  /// Example share message:
  /// ```
  /// Guarda questo evento su Nova: Torneo di Calcetto
  /// nova://events/123e4567-e89b-12d3-a456-426614174000
  /// ```
  static Future<void> shareEvent(Event event) async {
    final deepLink = _generateEventDeepLink(event.id);
    final message = _formatShareMessage(event.title, deepLink);

    try {
      final result = await Share.share(
        message,
        subject: 'Evento Nova: ${event.title}', // Used for email/messaging apps
      );

      if (result.status == ShareResultStatus.success) {
        // Successfully shared
        // TODO: Track share analytics (Phase 8)
      }
    } catch (e) {
      // Share failed - could show error snackbar
      throw ShareException('Failed to share event: $e');
    }
  }

  /// Share event with additional context (e.g., from event detail screen)
  ///
  /// Includes event description in the share message.
  static Future<void> shareEventDetailed(Event event) async {
    final deepLink = _generateEventDeepLink(event.id);
    final message = _formatDetailedShareMessage(
      event.title,
      event.description,
      event.formattedDateTime,
      event.location ?? 'Nessuna posizione',
      deepLink,
    );

    try {
      await Share.share(
        message,
        subject: 'Evento Nova: ${event.title}',
      );
    } catch (e) {
      throw ShareException('Failed to share event: $e');
    }
  }

  /// Generate deep link for event
  ///
  /// Format: nova://events/{event_id}
  static String _generateEventDeepLink(String eventId) {
    return 'nova://events/$eventId';
  }

  /// Format basic share message (for feed cards)
  static String _formatShareMessage(String eventTitle, String deepLink) {
    return 'Guarda questo evento su Nova: $eventTitle\n$deepLink';
  }

  /// Format detailed share message (for event detail screen)
  static String _formatDetailedShareMessage(
    String title,
    String description,
    String datetime,
    String location,
    String deepLink,
  ) {
    final truncatedDescription = description.length > 100
        ? '${description.substring(0, 100)}...'
        : description;

    return '''
Guarda questo evento su Nova:

📌 $title
📝 $truncatedDescription
📅 $datetime
📍 $location

Apri l'app Nova per vedere tutti i dettagli:
$deepLink
''';
  }

  /// Share generic text (for future use - e.g., profile sharing)
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      throw ShareException('Failed to share text: $e');
    }
  }

  /// Share with files (for future use - e.g., event flyer)
  static Future<void> shareWithFiles(
    String text,
    List<String> filePaths, {
    String? subject,
  }) async {
    try {
      await Share.shareXFiles(
        filePaths.map((path) => XFile(path)).toList(),
        text: text,
        subject: subject,
      );
    } catch (e) {
      throw ShareException('Failed to share with files: $e');
    }
  }
}

/// Exception thrown when sharing fails
class ShareException implements Exception {
  final String message;

  ShareException(this.message);

  @override
  String toString() => 'ShareException: $message';
}
