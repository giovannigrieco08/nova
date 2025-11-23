// Service: ShareService
// Feature: 006-user-profile (User Story 4 - T073)
// Purpose: Generate and share deep links for profiles

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/profile/domain/entities/profile.dart';

class ShareService {
  static const String deepLinkScheme = 'nova';
  static const String deepLinkBaseUrl = '$deepLinkScheme://';

  String generateProfileDeepLink(Profile profile) {
    return '${deepLinkBaseUrl}profile/@${profile.username}';
  }

  String generateProfileDeepLinkById(String userId) {
    return '${deepLinkBaseUrl}profile/$userId';
  }

  Future<void> copyProfileLink(Profile profile) async {
    final deepLink = generateProfileDeepLink(profile);
    await Clipboard.setData(ClipboardData(text: deepLink));
  }

  void shareProfileInChat(
    Profile profile, {
    required Function(String message) onNavigateToChat,
  }) {
    final deepLink = generateProfileDeepLink(profile);
    final displayName = profile.fullName ?? profile.username;
    final message = 'Guarda il profilo di $displayName: $deepLink';
    onNavigateToChat(message);
  }

  Future<void> shareProfileViaSystem(Profile profile) async {
    final deepLink = generateProfileDeepLink(profile);
    final displayName = profile.fullName ?? profile.username;
    final message = 'Guarda il profilo di $displayName su Nova: $deepLink';
    await Share.share(message, subject: 'Profilo Nova - $displayName');
  }

  String generateEventDeepLink(String eventId) {
    return '${deepLinkBaseUrl}event/$eventId';
  }
}
