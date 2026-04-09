import 'package:flutter/material.dart';
import '../../../../../core/theme/nova_colors.dart';
import '../../../../../core/theme/nova_spacing.dart';
import '../../../../../core/theme/nova_typography.dart';
import '../../../../../shared/widgets/adaptive/adaptive_switch.dart';

/// Read-only info tile (icon + title + value on trailing).
class SettingsReadOnlyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const SettingsReadOnlyTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: NovaColors.textSecondary(context)),
      title: Text(
        title,
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      trailing: Text(
        value,
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textSecondary(context),
        ),
      ),
    );
  }
}

/// Switch toggle tile.
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: NovaColors.textPrimary(context)),
      title: Text(title, style: NovaTypography.bodyMedium),
      subtitle: Text(
        subtitle,
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textSecondary(context),
        ),
      ),
      trailing: AdaptiveSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// Tappable action tile with chevron.
class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDestructive
        ? NovaColors.error(context)
        : NovaColors.textPrimary(context);

    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(
        title,
        style: NovaTypography.bodyMedium.copyWith(color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: NovaTypography.bodySmall.copyWith(
                color: isDestructive
                    ? NovaColors.error(context).withValues(alpha: 0.7)
                    : NovaColors.textSecondary(context),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: NovaColors.textTertiary(context),
      ),
      onTap: onTap,
    );
  }
}

/// Standard settings divider.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: NovaSpacing.large,
      color: NovaColors.divider(context),
    );
  }
}

/// Section header label.
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NovaSpacing.large,
        NovaSpacing.small,
        NovaSpacing.large,
        NovaSpacing.xsmall,
      ),
      child: Text(
        title.toUpperCase(),
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textTertiary(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Standard container decoration for a settings section card.
class SettingsSectionCard extends StatelessWidget {
  final Widget child;

  const SettingsSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
