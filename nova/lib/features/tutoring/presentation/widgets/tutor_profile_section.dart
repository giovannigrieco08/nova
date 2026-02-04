// Widget: TutorProfileSection
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Display tutor profile info in ProfileScreen/OtherProfileScreen

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart'
    show
        CupertinoButton,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../domain/entities/tutor_profile.dart';
import '../../data/repositories/tutor_repository.dart';
import '../providers/tutor_providers.dart';
import '../screens/edit_tutor_screen.dart';
import 'contact_tutor_sheet.dart';

/// TutorProfileSection - Displays tutor profile in user profile screens
///
/// **FR-019/FR-020**: Show tutor info in own and other profiles
///
/// **Features**:
/// - Subjects display with chips
/// - Price badge (Gratis or €X/h)
/// - Availability info
/// - "Contatta per Ripetizioni" button for other profiles
/// - Inactive state with "Riattiva" button
class TutorProfileSection extends ConsumerWidget {
  /// The tutor profile to display
  final TutorProfile profile;

  /// Whether this is the current user's profile
  final bool isOwnProfile;

  /// Author name for contact sheet (only for other profiles)
  final String? authorName;

  const TutorProfileSection({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.authorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show inactive state if profile is deactivated
    if (!profile.isActive && isOwnProfile) {
      return _buildInactiveCard(context, ref);
    }

    // Don't show inactive profiles for other users
    if (!profile.isActive && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    final card = Container(
      margin: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.m,
      ),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.border(context),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and badge
            _buildHeader(context),
            const SizedBox(height: NovaSpacing.m),

            // Subjects chips
            _buildSubjects(context),
            const SizedBox(height: NovaSpacing.m),

            // Price and availability row
            _buildPriceAndAvailability(context),

            // Bio if present
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const SizedBox(height: NovaSpacing.m),
              _buildBio(context),
            ],

            const SizedBox(height: NovaSpacing.l),

            // Action button
            _buildActionButton(context, ref),
          ],
        ),
      ),
    );

    // Wrap in GestureDetector for own profile to enable editing
    if (isOwnProfile) {
      return GestureDetector(
        onTap: () => _navigateToEdit(context),
        child: card,
      );
    }

    return card;
  }

  /// Navigate to EditTutorScreen
  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditTutorScreen(profile: profile),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [NovaColors.brandViolet, NovaColors.brandPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: NovaRadius.circularXs,
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: NovaSpacing.m),
        // Title
        Expanded(
          child: Text(
            'Ripetizioni',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: NovaColors.textPrimary(context),
            ),
          ),
        ),
        // Price badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: profile.isFree
                ? NovaColors.success(context).withValues(alpha: 0.15)
                : NovaColors.primary(context).withValues(alpha: 0.15),
            borderRadius: NovaRadius.circularL,
          ),
          child: Text(
            profile.priceDisplay,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: profile.isFree
                  ? NovaColors.success(context)
                  : NovaColors.primary(context),
            ),
          ),
        ),
        // Edit indicator for own profile
        if (isOwnProfile) ...[
          const SizedBox(width: NovaSpacing.s),
          Icon(
            Icons.edit_rounded,
            size: 18,
            color: NovaColors.textSecondary(context),
          ),
        ],
      ],
    );
  }

  Widget _buildSubjects(BuildContext context) {
    return Wrap(
      spacing: NovaSpacing.xs,
      runSpacing: NovaSpacing.xs,
      children: profile.subjects.map((subject) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: NovaColors.backgroundSecondary(context),
            borderRadius: NovaRadius.circularL,
            border: Border.all(
              color: NovaColors.border(context),
              width: 1,
            ),
          ),
          child: Text(
            subject.displayName,
            style: TextStyle(
              fontSize: 13,
              color: NovaColors.textPrimary(context),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceAndAvailability(BuildContext context) {
    final hasAvailability = profile.availabilityDays.isNotEmpty;
    final hasTimeSlot =
        profile.timeSlot != null && profile.timeSlot!.isNotEmpty;

    if (!hasAvailability && !hasTimeSlot) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: 16,
          color: NovaColors.textSecondary(context),
        ),
        const SizedBox(width: NovaSpacing.xs),
        Expanded(
          child: Text(
            _buildAvailabilityText(),
            style: TextStyle(
              fontSize: 13,
              color: NovaColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  String _buildAvailabilityText() {
    final parts = <String>[];

    if (profile.availabilityDays.isNotEmpty) {
      final days = profile.availabilityDays.map((d) => d.shortName).join(', ');
      parts.add(days);
    }

    if (profile.timeSlot != null && profile.timeSlot!.isNotEmpty) {
      parts.add(profile.timeSlot!);
    }

    return parts.join(' • ');
  }

  Widget _buildBio(BuildContext context) {
    return Text(
      profile.bio!,
      style: TextStyle(
        fontSize: 14,
        color: NovaColors.textSecondary(context),
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    // Don't show any button for own profile
    if (isOwnProfile) {
      return const SizedBox.shrink();
    } else {
      // "Contatta per Ripetizioni" button for other profiles
      return SizedBox(
        width: double.infinity,
        child: Platform.isIOS
            ? CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                color: NovaColors.primary(context),
                borderRadius: NovaRadius.circularS,
                onPressed: () => _showContactSheet(context),
                child: const Text(
                  'Contatta per Ripetizioni',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: () => _showContactSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NovaColors.primary(context),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: NovaRadius.circularS,
                  ),
                ),
                child: const Text(
                  'Contatta per Ripetizioni',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      );
    }
  }

  /// Build inactive profile card for own profile
  Widget _buildInactiveCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _navigateToEdit(context),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.l,
          vertical: NovaSpacing.m,
        ),
        decoration: BoxDecoration(
          color: NovaColors.card(context).withValues(alpha: 0.6),
          borderRadius: NovaRadius.circularM,
          border: Border.all(
            color: NovaColors.border(context),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NovaSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Grayed icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: NovaColors.textSecondary(context)
                          .withValues(alpha: 0.2),
                      borderRadius: NovaRadius.circularXs,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: NovaColors.textSecondary(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profilo Tutor Disattivato',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: NovaSpacing.xxs),
                        Text(
                          'Il tuo profilo non è visibile agli altri studenti',
                          style: TextStyle(
                            fontSize: 13,
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit indicator
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: NovaColors.textSecondary(context),
                  ),
                ],
              ),
              const SizedBox(height: NovaSpacing.l),
              // Reactivate button
              SizedBox(
                width: double.infinity,
                child: Platform.isIOS
                    ? CupertinoButton(
                        padding:
                            const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                        color: NovaColors.primary(context),
                        borderRadius: NovaRadius.circularS,
                        onPressed: () => _reactivateProfile(context, ref),
                        child: const Text(
                          'Riattiva Profilo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _reactivateProfile(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NovaColors.primary(context),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: NovaSpacing.m),
                          shape: RoundedRectangleBorder(
                            borderRadius: NovaRadius.circularS,
                          ),
                        ),
                        child: const Text(
                          'Riattiva Profilo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactSheet(BuildContext context) {
    final tutorWithAuthor = TutorProfileWithAuthorData(
      profile: profile,
      authorName: authorName ?? 'Tutor',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => ContactTutorSheet(
        tutor: tutorWithAuthor,
      ),
    );
  }

  Future<void> _reactivateProfile(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(toggleTutorActiveProvider.notifier);
    final result = await notifier.reactivate();

    if (result != null && context.mounted) {
      // Show success feedback
      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Profilo Riattivato'),
            content: const Text('Il tuo profilo tutor è di nuovo visibile.'),
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
            content: const Text('Profilo tutor riattivato!'),
            backgroundColor: NovaColors.success(context),
          ),
        );
      }
    }
  }
}
