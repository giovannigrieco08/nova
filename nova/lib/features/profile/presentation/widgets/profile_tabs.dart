// Widget: ProfileTabs
// Feature: 006-user-profile (User Story 1 - T036)
// Purpose: Platform-adaptive tabs for Eventi / Partecipazioni

import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Tab selection enum
enum ProfileTab {
  eventi,
  partecipazioni,
}

/// Platform-adaptive profile tabs widget
///
/// **Design**:
/// - iOS: CupertinoSegmentedControl with Cupertino design
/// - Android: TabBar with Material Design 3
/// - Tabs: "Eventi" | "Partecipazioni"
/// - For other user profiles, only "Eventi" tab is visible (privacy)
///
/// **Usage**:
/// ```dart
/// // Own profile (both tabs visible)
/// ProfileTabs(
///   selectedTab: ProfileTab.eventi,
///   onTabChanged: (tab) => setState(() => _selectedTab = tab),
///   showPartecipazioni: true,
/// )
///
/// // Other user profile (only Eventi tab)
/// ProfileTabs(
///   selectedTab: ProfileTab.eventi,
///   onTabChanged: (tab) => setState(() => _selectedTab = tab),
///   showPartecipazioni: false,
/// )
/// ```
class ProfileTabs extends StatelessWidget {
  final ProfileTab selectedTab;
  final ValueChanged<ProfileTab> onTabChanged;
  final bool showPartecipazioni; // Hide for other users' profiles (privacy)

  const ProfileTabs({
    required this.selectedTab,
    required this.onTabChanged,
    required this.showPartecipazioni,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSTabs(context);
    } else {
      return _buildAndroidTabs(context);
    }
  }

  /// Build iOS tabs with custom segmented control using NovaRadius.circularFull
  Widget _buildIOSTabs(BuildContext context) {
    // If showPartecipazioni is false, only show Eventi tab (no segmented control needed)
    if (!showPartecipazioni) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.large,
          vertical: NovaSpacing.medium,
        ),
        child: Text(
          'Eventi',
          style: NovaTypography.headingMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.large,
        vertical: NovaSpacing.medium,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: NovaColors.backgroundSecondary(context),
          borderRadius: NovaRadius.circularFull,
          border: Border.all(
            color: NovaColors.borderPrimary(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildIOSTab(
              context,
              label: 'Eventi',
              isSelected: selectedTab == ProfileTab.eventi,
              onTap: () => onTabChanged(ProfileTab.eventi),
              isFirst: true,
            ),
            _buildIOSTab(
              context,
              label: 'Partecipazioni',
              isSelected: selectedTab == ProfileTab.partecipazioni,
              onTap: () => onTabChanged(ProfileTab.partecipazioni),
              isFirst: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual iOS tab with pill-shaped selection
  Widget _buildIOSTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isFirst,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: NovaSpacing.small + 2),
          margin: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? NovaColors.brandViolet : Colors.transparent,
            borderRadius: NovaRadius.circularFull,
          ),
          child: Text(
            label,
            style: NovaTypography.bodyMedium.copyWith(
              color: isSelected ? Colors.white : NovaColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Build Android tabs with Material TabBar
  Widget _buildAndroidTabs(BuildContext context) {
    // If showPartecipazioni is false, only show Eventi header (no TabBar needed)
    if (!showPartecipazioni) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.large,
          vertical: NovaSpacing.medium,
        ),
        child: Text(
          'Eventi',
          style: NovaTypography.headingMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.large),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: NovaColors.borderPrimary(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildAndroidTab(
            context,
            label: 'Eventi',
            isSelected: selectedTab == ProfileTab.eventi,
            onTap: () => onTabChanged(ProfileTab.eventi),
          ),
          _buildAndroidTab(
            context,
            label: 'Partecipazioni',
            isSelected: selectedTab == ProfileTab.partecipazioni,
            onTap: () => onTabChanged(ProfileTab.partecipazioni),
          ),
        ],
      ),
    );
  }

  /// Build individual Android tab
  Widget _buildAndroidTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: NovaSpacing.medium),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? NovaColors.brandViolet : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: NovaTypography.bodyMedium.copyWith(
              color: isSelected ? NovaColors.brandViolet : NovaColors.textSecondary(context),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
