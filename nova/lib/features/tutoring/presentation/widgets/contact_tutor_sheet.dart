// Widget: ContactTutorSheet
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Bottom sheet for contacting a tutor via WhatsApp/Instagram

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../data/repositories/tutor_repository.dart';

/// ContactTutorSheet - Bottom sheet for contacting a tutor
///
/// Displays tutor info and contact buttons for WhatsApp and Instagram.
/// Uses HTTPS deep links with automatic fallback to browser.
///
/// FR-007: Contatta via WhatsApp (https://wa.me/{phone})
/// FR-008: Contatta via Instagram (https://instagram.com/{username})
class ContactTutorSheet extends StatelessWidget {
  /// Tutor profile with author data
  final TutorProfileWithAuthorData tutor;

  /// Optional pre-filled message for WhatsApp
  final String? whatsappMessage;

  const ContactTutorSheet({
    super.key,
    required this.tutor,
    this.whatsappMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.border(context),
                borderRadius: NovaRadius.circularXxs,
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(NovaSpacing.xl),
              child: Column(
                children: [
                  // Tutor avatar and name
                  _buildTutorHeader(context),
                  const SizedBox(height: NovaSpacing.xl),
                  // Bio (if available)
                  if (tutor.profile.bio != null && tutor.profile.bio!.isNotEmpty) ...[
                    Text(
                      tutor.profile.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.l),
                  ],
                  // Availability info
                  if (tutor.profile.availabilityDays.isNotEmpty) ...[
                    _buildInfoRow(
                      context,
                      icon: Platform.isIOS
                          ? CupertinoIcons.calendar
                          : Icons.calendar_today_outlined,
                      text: tutor.profile.availabilityDisplay,
                    ),
                    if (tutor.profile.timeSlot != null)
                      _buildInfoRow(
                        context,
                        icon: Platform.isIOS
                            ? CupertinoIcons.clock
                            : Icons.access_time,
                        text: tutor.profile.timeSlot!,
                      ),
                    const SizedBox(height: NovaSpacing.l),
                  ],
                  // Contact buttons
                  _buildContactButtons(context),
                  const SizedBox(height: NovaSpacing.m),
                  // Copy contact fallback
                  _buildCopyButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorHeader(BuildContext context) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: NovaColors.primary(context),
              width: 3,
            ),
          ),
          child: ClipOval(
            child: tutor.authorAvatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: tutor.authorAvatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildAvatarPlaceholder(context),
                    errorWidget: (_, __, ___) => _buildAvatarPlaceholder(context),
                  )
                : _buildAvatarPlaceholder(context),
          ),
        ),
        const SizedBox(height: NovaSpacing.m),
        // Name
        Text(
          tutor.authorName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: NovaColors.textPrimary(context),
          ),
        ),
        if (tutor.authorClass != null) ...[
          const SizedBox(height: NovaSpacing.xs),
          Text(
            tutor.authorClass!,
            style: TextStyle(
              fontSize: 14,
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
        const SizedBox(height: NovaSpacing.s),
        // Price and subjects
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NovaSpacing.s,
                vertical: NovaSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: tutor.profile.isFree
                    ? NovaColors.success(context).withValues(alpha: 0.1)
                    : NovaColors.primary(context).withValues(alpha: 0.1),
                borderRadius: NovaRadius.circularXs,
              ),
              child: Text(
                tutor.profile.priceDisplay,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tutor.profile.isFree
                      ? NovaColors.success(context)
                      : NovaColors.primary(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(BuildContext context) {
    final initials = tutor.authorName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      color: NovaColors.primary(context).withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: NovaColors.primary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NovaSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: NovaColors.textSecondary(context),
          ),
          const SizedBox(width: NovaSpacing.s),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButtons(BuildContext context) {
    return Row(
      children: [
        // WhatsApp button
        if (tutor.profile.hasWhatsApp)
          Expanded(
            child: _buildContactButton(
              context,
              label: 'WhatsApp',
              icon: Icons.chat_rounded,
              color: NovaColors.whatsappGreen,
              onTap: () => _openWhatsApp(context),
            ),
          ),
        if (tutor.profile.hasWhatsApp && tutor.profile.hasInstagram)
          const SizedBox(width: NovaSpacing.m),
        // Instagram button
        if (tutor.profile.hasInstagram)
          Expanded(
            child: _buildContactButton(
              context,
              label: 'Instagram',
              icon: Icons.camera_alt_rounded,
              color: NovaColors.instagramPink,
              onTap: () => _openInstagram(context),
            ),
          ),
      ],
    );
  }

  Widget _buildContactButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    if (Platform.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: NovaRadius.circularS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: NovaSpacing.s),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: NovaRadius.circularS,
        ),
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _copyContact(context),
      icon: Icon(
        Platform.isIOS ? CupertinoIcons.doc_on_doc : Icons.copy,
        size: 18,
        color: NovaColors.textSecondary(context),
      ),
      label: Text(
        'Copia contatto',
        style: TextStyle(
          color: NovaColors.textSecondary(context),
        ),
      ),
    );
  }

  /// Open WhatsApp with pre-filled message
  /// Uses HTTPS URL for automatic fallback to browser
  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = tutor.profile.whatsappPhone;
    if (phone == null) return;

    // Build message
    final message = whatsappMessage ??
        'Ciao, ti contatto per ripetizioni di ${tutor.profile.subjectsDisplay}';
    final encodedMessage = Uri.encodeComponent(message);

    // Build URL (HTTPS for automatic fallback)
    final url = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Show error and copy fallback
      if (context.mounted) {
        _showErrorSnackBar(context, 'Impossibile aprire WhatsApp');
        await Clipboard.setData(ClipboardData(text: phone));
      }
    }
  }

  /// Open Instagram profile
  /// Uses HTTPS URL for automatic fallback to browser
  Future<void> _openInstagram(BuildContext context) async {
    final username = tutor.profile.instagramUsername;
    if (username == null) return;

    // Build URL (HTTPS for automatic fallback)
    final url = Uri.parse('https://instagram.com/$username');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Show error and copy fallback
      if (context.mounted) {
        _showErrorSnackBar(context, 'Impossibile aprire Instagram');
        await Clipboard.setData(ClipboardData(text: '@$username'));
      }
    }
  }

  /// Copy contact to clipboard
  Future<void> _copyContact(BuildContext context) async {
    String contact = '';

    if (tutor.profile.hasWhatsApp) {
      contact += 'WhatsApp: ${tutor.profile.whatsappPhone}';
    }
    if (tutor.profile.hasInstagram) {
      if (contact.isNotEmpty) contact += '\n';
      contact += 'Instagram: @${tutor.profile.instagramUsername}';
    }

    await Clipboard.setData(ClipboardData(text: contact));

    if (context.mounted) {
      _showSuccessSnackBar(context, 'Contatto copiato');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Errore'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: NovaColors.error(context),
        ),
      );
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    if (Platform.isIOS) {
      // On iOS, just pop the sheet
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: NovaColors.success(context),
        ),
      );
    }
  }
}
