import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive icons using native SF Symbols (iOS) and Material Icons (Android).
///
/// Usage:
/// ```dart
/// NovaIcons.home(context)
/// NovaIcons.camera(context, size: 32, color: Colors.white)
/// ```
class NovaIcons {
  // Prevent instantiation
  NovaIcons._();

  /// Helper to create adaptive icons
  ///
  /// - iOS: Native SF Symbol via CNIcon (cupertino_native)
  /// - Android: Material Icon
  static Widget adaptive(
    BuildContext context, {
    required String sfSymbol,
    required IconData materialIcon,
    double? size,
    Color? color,
  }) {
    if (context.isIOS) {
      // iOS: Native SF Symbol via CNIcon from cupertino_native
      return CNIcon(
        symbol: CNSymbol(sfSymbol),
        size: size,
        color: color,
      );
    }

    // Android: Material Icon
    return Icon(
      materialIcon,
      size: size,
      color: color,
    );
  }

  // ==================== Main Navigation Icons ====================

  static Widget home(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'house.fill',
      materialIcon: Icons.home,
      size: size,
      color: color,
    );
  }

  static Widget events(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'calendar',
      materialIcon: Icons.event,
      size: size,
      color: color,
    );
  }

  static Widget camera(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'camera.fill',
      materialIcon: Icons.camera_alt,
      size: size,
      color: color,
    );
  }

  static Widget chat(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'message.fill',
      materialIcon: Icons.chat_bubble,
      size: size,
      color: color,
    );
  }

  static Widget profile(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'person.circle.fill',
      materialIcon: Icons.person,
      size: size,
      color: color,
    );
  }

  // ==================== Common Action Icons ====================

  static Widget notifications(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'bell',
      materialIcon: Icons.notifications_outlined,
      size: size,
      color: color,
    );
  }

  static Widget notificationsFilled(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'bell.fill',
      materialIcon: Icons.notifications,
      size: size,
      color: color,
    );
  }

  static Widget heart(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'heart',
      materialIcon: Icons.favorite_border,
      size: size,
      color: color,
    );
  }

  static Widget heartFilled(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'heart.fill',
      materialIcon: Icons.favorite,
      size: size,
      color: color,
    );
  }

  static Widget search(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'magnifyingglass',
      materialIcon: Icons.search,
      size: size,
      color: color,
    );
  }

  static Widget settings(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'gearshape.fill',
      materialIcon: Icons.settings,
      size: size,
      color: color,
    );
  }

  static Widget share(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'square.and.arrow.up',
      materialIcon: Icons.share,
      size: size,
      color: color,
    );
  }

  // ==================== Navigation Icons ====================

  static Widget chevronRight(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'chevron.right',
      materialIcon: Icons.chevron_right,
      size: size,
      color: color,
    );
  }

  static Widget chevronLeft(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'chevron.left',
      materialIcon: Icons.chevron_left,
      size: size,
      color: color,
    );
  }

  static Widget close(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'xmark',
      materialIcon: Icons.close,
      size: size,
      color: color,
    );
  }

  static Widget add(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'plus',
      materialIcon: Icons.add,
      size: size,
      color: color,
    );
  }

  static Widget check(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'checkmark',
      materialIcon: Icons.check,
      size: size,
      color: color,
    );
  }

  // ==================== Content Icons ====================

  static Widget location(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'mappin.circle.fill',
      materialIcon: Icons.location_on,
      size: size,
      color: color,
    );
  }

  static Widget calendar(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'calendar',
      materialIcon: Icons.calendar_today,
      size: size,
      color: color,
    );
  }

  static Widget more(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'ellipsis',
      materialIcon: Icons.more_vert,
      size: size,
      color: color,
    );
  }

  static Widget photo(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'photo',
      materialIcon: Icons.image,
      size: size,
      color: color,
    );
  }

  static Widget person(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'person',
      materialIcon: Icons.person_outline,
      size: size,
      color: color,
    );
  }

  static Widget personFilled(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'person.fill',
      materialIcon: Icons.person,
      size: size,
      color: color,
    );
  }

  // ==================== Status Icons ====================

  static Widget info(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'info.circle',
      materialIcon: Icons.info_outline,
      size: size,
      color: color,
    );
  }

  static Widget warning(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'exclamationmark.triangle',
      materialIcon: Icons.warning_outlined,
      size: size,
      color: color,
    );
  }

  static Widget error(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'xmark.circle',
      materialIcon: Icons.error_outline,
      size: size,
      color: color,
    );
  }

  static Widget success(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'checkmark.circle',
      materialIcon: Icons.check_circle_outline,
      size: size,
      color: color,
    );
  }
}
