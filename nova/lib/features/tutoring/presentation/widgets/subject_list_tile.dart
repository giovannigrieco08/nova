// Widget: SubjectListTile
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Fiverr-style list tile for subject selection

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../domain/entities/subject.dart';

/// SubjectListTile - Fiverr-style list tile for subject selection
///
/// Displays:
/// - Purple stylized icon on the left (no gradient)
/// - Subject title (bold)
/// - Subject description (secondary text)
/// - Divider between items
class SubjectListTile extends StatelessWidget {
  /// The subject to display
  final Subject subject;

  /// Callback when tile is tapped
  final VoidCallback onTap;

  /// Whether to show divider below
  final bool showDivider;

  const SubjectListTile({
    super.key,
    required this.subject,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getSubjectIcon(subject);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Platform.isIOS
            ? _buildCupertinoTile(context, icon)
            : _buildMaterialTile(context, icon),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 80, // Align with text, not icon
            color: NovaColors.border(context).withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildCupertinoTile(BuildContext context, IconData icon) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: _buildTileContent(context, icon),
    );
  }

  Widget _buildMaterialTile(BuildContext context, IconData icon) {
    return InkWell(
      onTap: onTap,
      child: _buildTileContent(context, icon),
    );
  }

  Widget _buildTileContent(BuildContext context, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.m,
      ),
      child: Row(
        children: [
          // Icon container (purple, no gradient)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: NovaColors.brandViolet.withValues(alpha: 0.1),
              borderRadius: NovaRadius.circularS,
            ),
            child: Icon(
              icon,
              color: NovaColors.brandViolet,
              size: 28,
            ),
          ),
          const SizedBox(width: NovaSpacing.m),
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subject.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: NovaColors.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Chevron indicator
          Icon(
            Platform.isIOS
                ? CupertinoIcons.chevron_right
                : Icons.chevron_right,
            color: NovaColors.textSecondary(context),
            size: 20,
          ),
        ],
      ),
    );
  }

  /// Get appropriate icon for each subject
  IconData _getSubjectIcon(Subject subject) {
    switch (subject) {
      case Subject.matematica:
        return Icons.calculate_outlined;
      case Subject.fisica:
        return Icons.science_outlined;
      case Subject.latino:
        return Icons.history_edu_outlined;
      case Subject.greco:
        return Icons.temple_buddhist_outlined;
      case Subject.inglese:
        return Icons.language_outlined;
      case Subject.italiano:
        return Icons.menu_book_outlined;
      case Subject.informatica:
        return Icons.computer_outlined;
      case Subject.storia:
        return Icons.account_balance_outlined;
      case Subject.filosofia:
        return Icons.psychology_outlined;
      case Subject.scienze:
        return Icons.biotech_outlined;
      case Subject.arte:
        return Icons.palette_outlined;
    }
  }
}
