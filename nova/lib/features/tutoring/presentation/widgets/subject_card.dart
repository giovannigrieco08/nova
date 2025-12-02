// Widget: SubjectCard
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Grid card for subject selection in SubjectsScreen

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../domain/entities/subject.dart';

/// SubjectCard - Tappable card displaying a school subject
///
/// Used in SubjectsScreen grid for subject selection.
/// Platform-adaptive: Cupertino on iOS, Material on Android.
class SubjectCard extends StatelessWidget {
  /// The subject to display
  final Subject subject;

  /// Callback when card is tapped
  final VoidCallback onTap;

  /// Number of tutors available for this subject (optional)
  final int? tutorCount;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    this.tutorCount,
  });

  @override
  Widget build(BuildContext context) {
    // Get icon for subject
    final icon = _getSubjectIcon(subject);

    return Platform.isIOS ? _buildCupertinoCard(context, icon) : _buildMaterialCard(context, icon);
  }

  Widget _buildCupertinoCard(BuildContext context, IconData icon) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: _buildCardContent(context, icon),
    );
  }

  Widget _buildMaterialCard(BuildContext context, IconData icon) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _buildCardContent(context, icon),
    );
  }

  Widget _buildCardContent(BuildContext context, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NovaColors.border(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: NovaColors.isDark(context)
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [NovaColors.brandViolet, NovaColors.brandPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: NovaSpacing.m),
            // Subject name
            Text(
              subject.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NovaColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Tutor count (if available)
            if (tutorCount != null) ...[
              const SizedBox(height: NovaSpacing.xs),
              Text(
                '$tutorCount tutor',
                style: TextStyle(
                  fontSize: 12,
                  color: NovaColors.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get appropriate icon for each subject
  IconData _getSubjectIcon(Subject subject) {
    switch (subject) {
      case Subject.matematica:
        return Icons.calculate_rounded;
      case Subject.fisica:
        return Icons.science_rounded;
      case Subject.latino:
        return Icons.history_edu_rounded;
      case Subject.greco:
        return Icons.temple_buddhist_rounded;
      case Subject.inglese:
        return Icons.language_rounded;
      case Subject.italiano:
        return Icons.menu_book_rounded;
      case Subject.informatica:
        return Icons.computer_rounded;
      case Subject.storia:
        return Icons.account_balance_rounded;
      case Subject.filosofia:
        return Icons.psychology_rounded;
      case Subject.scienze:
        return Icons.biotech_rounded;
      case Subject.arte:
        return Icons.palette_rounded;
      case Subject.francese:
        return Icons.translate_rounded;
    }
  }
}
