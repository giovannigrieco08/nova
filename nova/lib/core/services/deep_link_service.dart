// =====================================================================
// Nova - Deep Link Service
// =====================================================================
// Purpose: Handle incoming deep links and route to authentication
// Architecture: Singleton service with app_links package
// =====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

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
      if (initialUri != null) {
        assert(() {
          debugPrint('🔗 Deep link: App launched from link');
          debugPrint('   URI: $initialUri');
          return true;
        }());

        // Handle initial link
        await onLink(initialUri);
      }

      // Listen for deep links while app is running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          assert(() {
            debugPrint('🔗 Deep link: Received while app running');
            debugPrint('   URI: $uri');
            return true;
          }());

          // Handle incoming link
          await onLink(uri);
        },
        onError: (error) {
          assert(() {
            debugPrint('❌ Deep link error: $error');
            return true;
          }());
        },
      );

      assert(() {
        debugPrint('✅ Deep link service initialized');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('❌ Failed to initialize deep link service: $e');
        return true;
      }());
      rethrow;
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;

    assert(() {
      debugPrint('🧹 Deep link service disposed');
      return true;
    }());
  }
}
