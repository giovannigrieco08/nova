// Widget: NovaTabs
// Purpose: Custom tab bar with minimal BeReal-inspired design

import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';

/// Custom TabBar with minimal design
///
/// Features:
/// - Two tabs with custom labels
/// - Active tab: bold text + colored underline
/// - Inactive tab: gray text
/// - Smooth animations
/// - Clean minimal design
class NovaTabs extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final String tab1Label;
  final String tab2Label;

  const NovaTabs({
    super.key,
    required this.controller,
    this.tab1Label = 'Eventi',
    this.tab2Label = 'Bacheche',
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: NovaColors.surface(context),
      child: TabBar(
        controller: controller,
        indicatorColor: NovaColors.primary(context),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: NovaColors.textPrimary(context),
        unselectedLabelColor: NovaColors.textSecondary(context),
        labelStyle: NovaTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: NovaTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w400,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
        tabs: [
          Tab(text: tab1Label),
          Tab(text: tab2Label),
        ],
      ),
    );
  }
}
