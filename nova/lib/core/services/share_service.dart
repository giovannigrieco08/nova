// Core Service: ShareService
// Feature: 004-event-creation-moderation (US4 - Event Sharing)
// Extended: 006-user-profile (US4 - Profile Sharing)
// Purpose: Share events and profiles via native share sheet with deep links
//
// Architecture:
// - Uses Supabase Edge Function to generate landing pages with Open Graph meta tags
// - Landing pages show rich previews in WhatsApp/Telegram (image, title, description)
// - Auto-redirects to app via nova:// deep link scheme
//
// URL Formats:
// - Development: https://PROJECT.supabase.co/functions/v1/share-redirect/events/{id}
// - Production (Supabase Pro): https://nova.galileimoro.edu.it/events/{id}
//
// Usage:
// ```dart
// await ShareService.shareEvent(event);
// final service = ShareService();
// await service.copyProfileLink(profile);
// ```

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/events/domain/entities/event.dart';
import '../../features/profile/domain/entities/profile.dart';
import '../config/supabase_config.dart';

/// Service for sharing Nova content via native share sheet
class ShareService {
  /// Default constructor for instance usage (profile sharing)
  ShareService();

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
      await Share.share(
        message,
        subject: 'Evento Nova: ${event.title}', // Used for email/messaging apps
      );

      // Share sheet was opened successfully
      // TODO: Track share analytics (Phase 8)
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

  /// Base URL for share links
  ///
  /// Uses Supabase Edge Function URL which:
  /// - Generates landing page with Open Graph meta tags (for WhatsApp/Telegram previews)
  /// - Auto-redirects to app via nova:// deep link
  ///
  /// With Supabase Pro, you can configure a custom domain (e.g., nova.galileimoro.edu.it)
  /// to replace the default Supabase function URL.
  static String get _baseUrl {
    // Get Supabase URL and append the edge function path
    final supabaseUrl = SupabaseConfig.supabaseUrl;
    return '$supabaseUrl/functions/v1/share-redirect';

    // When using Supabase Pro with custom domain, replace with:
    // return 'https://nova.galileimoro.edu.it';
  }

  /// Generate deep link for event
  ///
  /// Format: {baseUrl}/events/{event_id}
  /// The Edge Function returns HTML with Open Graph tags for rich previews
  static String _generateEventDeepLink(String eventId) {
    return '$_baseUrl/events/$eventId';
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

  // =========================================================================
  // PROFILE SHARING (006-user-profile US4)
  // =========================================================================

  /// Copy profile deep link to clipboard
  ///
  /// Deep link format: nova://profiles/{user_id}
  Future<void> copyProfileLink(Profile profile) async {
    final deepLink = _generateProfileDeepLink(profile.userId);
    await Clipboard.setData(ClipboardData(text: deepLink));
  }

  /// Share profile in chat with pre-filled message
  ///
  /// Generates share message and navigates to chat via callback
  void shareProfileInChat(
    Profile profile, {
    required void Function(String message) onNavigateToChat,
  }) {
    final deepLink = _generateProfileDeepLink(profile.userId);
    final displayName = profile.fullName.isNotEmpty ? profile.fullName : profile.username;
    final message = 'Dai un\'occhiata al profilo di $displayName su Nova!\n$deepLink';
    onNavigateToChat(message);
  }

  /// Share profile via native share sheet
  Future<void> shareProfile(Profile profile) async {
    final deepLink = _generateProfileDeepLink(profile.userId);
    final displayName = profile.fullName.isNotEmpty ? profile.fullName : profile.username;
    final message = 'Dai un\'occhiata al profilo di $displayName su Nova!\n$deepLink';

    try {
      await Share.share(
        message,
        subject: 'Profilo Nova: $displayName',
      );
    } catch (e) {
      throw ShareException('Failed to share profile: $e');
    }
  }

  /// Generate deep link for profile
  ///
  /// Format: {baseUrl}/profiles/{user_id}
  /// The Edge Function returns HTML with Open Graph tags for rich previews
  static String _generateProfileDeepLink(String userId) {
    return '$_baseUrl/profiles/$userId';
  }
}

/// Exception thrown when sharing fails
class ShareException implements Exception {
  final String message;

  ShareException(this.message);

  @override
  String toString() => 'ShareException: $message';
}
