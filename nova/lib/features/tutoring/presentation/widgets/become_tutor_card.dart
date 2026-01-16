// Widget: BecomeTutorCard
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: CTA card encouraging users to become tutors

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';

/// BecomeTutorCard - Call-to-action card for becoming a tutor
///
/// Displayed in ProfileScreen when user is not yet a tutor.
/// Encourages peer-to-peer tutoring participation.
///
/// FR-011: CTA "Vuoi dare ripetizioni?"
class BecomeTutorCard extends StatelessWidget {
  /// Callback when card is tapped
  final VoidCallback onTap;

  const BecomeTutorCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.m,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [NovaColors.brandViolet, NovaColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: NovaRadius.circularM,
        boxShadow: [
          BoxShadow(
            color: NovaColors.brandViolet.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: NovaRadius.circularM,
          child: Padding(
            padding: const EdgeInsets.all(NovaSpacing.l),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: NovaRadius.circularS,
                  ),
                  child: Icon(
                    Platform.isIOS
                        ? CupertinoIcons.book_fill
                        : Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: NovaSpacing.m),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vuoi dare ripetizioni?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: NovaSpacing.xxs),
                      Text(
                        'Aiuta i tuoi compagni e guadagna',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Platform.isIOS
                      ? CupertinoIcons.chevron_forward
                      : Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
