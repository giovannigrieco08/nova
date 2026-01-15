// Widget: ProfileTabs
// Feature: 006-user-profile (User Story 1 - T036)
// Purpose: Platform-adaptive tabs for Eventi / Partecipazioni

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../../../../core/theme/nova_colors.dart';
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

  /// Build iOS tabs with CupertinoSegmentedControl
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
      child: CupertinoSegmentedControl<ProfileTab>(
        children: {
          ProfileTab.eventi: Padding(
            padding: EdgeInsets.symmetric(vertical: NovaSpacing.small),
            child: Text(
              'Eventi',
              style: NovaTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ProfileTab.partecipazioni: Padding(
            padding: EdgeInsets.symmetric(vertical: NovaSpacing.small),
            child: Text(
              'Partecipazioni',
              style: NovaTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        },
        groupValue: selectedTab,
        onValueChanged: onTabChanged,
        selectedColor: NovaColors.brandViolet,
        unselectedColor: NovaColors.backgroundSecondary(context),
        borderColor: NovaColors.borderPrimary(context),
        pressedColor: NovaColors.brandViolet.withValues(alpha: 0.3),
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
