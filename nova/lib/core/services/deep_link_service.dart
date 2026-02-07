// =====================================================================
// Nova - Deep Link Service
// =====================================================================
// Purpose: Handle incoming deep links and route to authentication
// Architecture: Singleton service with app_links package
// =====================================================================

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Deep link handling service
///
/// Responsibilities:
/// - Listen for incoming deep links (app_links stream)
/// - Extract URI from deep link
/// - Invoke callback with URI
///
/// Usage:
/// ```dart
/// final deepLinkService = DeepLinkService();
/// await deepLinkService.initialize(
///   onLink: (uri) async {
///     // Handle deep link
///     await authRepo.verifyMagicLink(uri);
///   },
/// );
/// ```
class DeepLinkService {
  /// App links instance
  final AppLinks _appLinks = AppLinks();

  /// Stream subscription (for cleanup)
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialize deep link handling
  ///
  /// Checks for initial link (app launched from link),
  /// then listens for incoming links while app is running.
  ///
  /// Parameters:
  /// - [onLink]: Callback invoked when deep link received
  ///
  /// Returns:
  /// - Future that completes when initialization done
  Future<void> initialize({
    required Future<void> Function(Uri uri) onLink,
  }) async {
    try {
      // Check if app was launched from a deep link
      final initialUri = await _appLinks.getInitialLink();
      debugPrint('🔗 [DeepLinkService] Initial link: $initialUri');

      if (initialUri != null) {
        // Handle initial link
        debugPrint('🔗 [DeepLinkService] Processing initial link...');
        await onLink(initialUri);
      }

      // Listen for deep links while app is running
      debugPrint('🔗 [DeepLinkService] Setting up stream listener...');
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          // Handle incoming link
          debugPrint('🔗 [DeepLinkService] Stream received: $uri');
          await onLink(uri);
        },
        onError: (error) {
          // Deep link error - log it
          debugPrint('🔗 [DeepLinkService] Stream error: $error');
        },
      );
      debugPrint('🔗 [DeepLinkService] Initialization complete');
    } catch (e) {
      debugPrint('🔗 [DeepLinkService] Initialization error: $e');
      rethrow;
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
