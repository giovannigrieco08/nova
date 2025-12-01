/// Search results section widget
///
/// Displays a section header with count and list of results.
/// Used for "Eventi (N)" and "Utenti (N)" sections.

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Section widget for search results with header
class SearchResultsSection extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;
  final bool showDivider;

  const SearchResultsSection({
    super.key,
    required this.title,
    required this.count,
    required this.children,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.s,
          ),
          child: Row(
            children: [
              Text(
                title,
                style: NovaTextStyles.h3.copyWith(
                  color: NovaColors.textPrimaryStatic,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: NovaSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NovaSpacing.xs,
                  vertical: NovaSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: NovaColors.dividerLight,
                  borderRadius: NovaRadius.circularS,
                ),
                child: Text(
                  count.toString(),
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.textSecondaryStatic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Results list
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l),
          child: Column(
            children: children
                .map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: NovaSpacing.xs),
                      child: child,
                    ))
                .toList(),
          ),
        ),
        // Divider between sections
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NovaSpacing.s),
            child: Divider(
              color: NovaColors.borderLight,
              height: 1,
            ),
          ),
      ],
    );
  }
}
