// Widget: ShareProfileSheet
// Feature: 006-user-profile (User Story 4 - T074)
// Purpose: Platform-adaptive bottom sheet for profile sharing options

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../../domain/entities/profile.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

class ShareProfileSheet extends StatelessWidget {
  final Profile profile;
  final ShareService shareService;
  
  const ShareProfileSheet({
    required this.profile,
    required this.shareService,
    super.key,
  });

  static void show(BuildContext context, Profile profile) {
    final shareService = ShareService();
    
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => ShareProfileSheet(
          profile: profile,
          shareService: shareService,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (_) => ShareProfileSheet(
          profile: profile,
          shareService: shareService,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoActionSheet(
        title: Text('Condividi Profilo', style: NovaTypography.headingSmall),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _copyLink(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.link, size: 20),
                SizedBox(width: NovaSpacing.small),
                Text('Copia Link', style: NovaTypography.bodyMedium),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _shareInChat(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.chat_bubble, size: 20),
                SizedBox(width: NovaSpacing.small),
                Text('Condividi in Chat', style: NovaTypography.bodyMedium),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Annulla', style: NovaTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ),
      );
    } else {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.medium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Condividi Profilo', style: NovaTypography.headingSmall),
              SizedBox(height: NovaSpacing.medium),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text('Copia Link', style: NovaTypography.bodyMedium),
                onTap: () => _copyLink(context),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_rounded),
                title: Text('Condividi in Chat', style: NovaTypography.bodyMedium),
                onTap: () => _shareInChat(context),
              ),
              SizedBox(height: NovaSpacing.small),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annulla', style: NovaTypography.bodyMedium.copyWith(color: NovaColors.textSecondary)),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _copyLink(BuildContext context) async {
    await shareService.copyProfileLink(profile);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiato!')),
      );
    }
  }

  void _shareInChat(BuildContext context) {
    shareService.shareProfileInChat(
      profile,
      onNavigateToChat: (message) {
        Navigator.pop(context);
        // TODO(T077): Navigate to Chat tab with pre-filled message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat coming soon!')),
        );
      },
    );
  }
}
