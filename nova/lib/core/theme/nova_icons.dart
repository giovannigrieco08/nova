import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive icons using CupertinoIcons (iOS) and Material Icons (Android).
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
  /// - iOS: CupertinoIcons (SF Symbols compatible)
  /// - Android: Material Icon
  static Widget adaptive(
    BuildContext context, {
    required String sfSymbol, // Kept for reference, but using cupertinoIcon instead
    required IconData materialIcon,
    IconData? cupertinoIcon, // Optional CupertinoIcons fallback
    double? size,
    Color? color,
  }) {
    if (context.isIOS) {
      // iOS: Use CupertinoIcons (guaranteed to work)
      return Icon(
        cupertinoIcon ?? materialIcon,
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
      cupertinoIcon: CupertinoIcons.house_fill,
      size: size,
      color: color,
    );
  }

  static Widget events(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'calendar',
      materialIcon: Icons.event,
      cupertinoIcon: CupertinoIcons.calendar,
      size: size,
      color: color,
    );
  }

  static Widget camera(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'camera.fill',
      materialIcon: Icons.camera_alt,
      cupertinoIcon: CupertinoIcons.camera_fill,
      size: size,
      color: color,
    );
  }

  static Widget chat(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'message.fill',
      materialIcon: Icons.chat_bubble,
      cupertinoIcon: CupertinoIcons.chat_bubble_fill,
      size: size,
      color: color,
    );
  }

  static Widget profile(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'person.circle.fill',
      materialIcon: Icons.person,
      cupertinoIcon: CupertinoIcons.person_circle_fill,
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
      cupertinoIcon: CupertinoIcons.bell,
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
      cupertinoIcon: CupertinoIcons.bell_fill,
      size: size,
      color: color,
    );
  }

  static Widget heart(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'heart',
      materialIcon: Icons.favorite_border,
      cupertinoIcon: CupertinoIcons.heart,
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
      cupertinoIcon: CupertinoIcons.heart_fill,
      size: size,
      color: color,
    );
  }

  static Widget search(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'magnifyingglass',
      materialIcon: Icons.search,
      cupertinoIcon: CupertinoIcons.search,
      size: size,
      color: color,
    );
  }

  static Widget settings(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'gearshape.fill',
      materialIcon: Icons.settings,
      cupertinoIcon: CupertinoIcons.gear_solid,
      size: size,
      color: color,
    );
  }

  static Widget share(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'square.and.arrow.up',
      materialIcon: Icons.share,
      cupertinoIcon: CupertinoIcons.share,
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
      cupertinoIcon: CupertinoIcons.chevron_right,
      size: size,
      color: color,
    );
  }

  static Widget chevronLeft(BuildContext context,
      {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'chevron.left',
      materialIcon: Icons.arrow_back_ios_new,
      cupertinoIcon: CupertinoIcons.chevron_left,
      size: size,
      color: color,
    );
  }

  static Widget close(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'xmark',
      materialIcon: Icons.close,
      cupertinoIcon: CupertinoIcons.xmark,
      size: size,
      color: color,
    );
  }

  static Widget add(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'plus',
      materialIcon: Icons.add,
      cupertinoIcon: CupertinoIcons.add,
      size: size,
      color: color,
    );
  }

  static Widget check(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'checkmark',
      materialIcon: Icons.check,
      cupertinoIcon: CupertinoIcons.checkmark,
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
      cupertinoIcon: CupertinoIcons.location_solid,
      size: size,
      color: color,
    );
  }

  static Widget calendar(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'calendar',
      materialIcon: Icons.calendar_today,
      cupertinoIcon: CupertinoIcons.calendar,
      size: size,
      color: color,
    );
  }

  static Widget more(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'ellipsis',
      materialIcon: Icons.more_vert,
      cupertinoIcon: CupertinoIcons.ellipsis_vertical,
      size: size,
      color: color,
    );
  }

  static Widget photo(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'photo',
      materialIcon: Icons.image,
      cupertinoIcon: CupertinoIcons.photo,
      size: size,
      color: color,
    );
  }

  static Widget person(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'person',
      materialIcon: Icons.person_outline,
      cupertinoIcon: CupertinoIcons.person,
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
      cupertinoIcon: CupertinoIcons.person_fill,
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
      cupertinoIcon: CupertinoIcons.info_circle,
      size: size,
      color: color,
    );
  }

  static Widget warning(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'exclamationmark.triangle',
      materialIcon: Icons.warning_outlined,
      cupertinoIcon: CupertinoIcons.exclamationmark_triangle,
      size: size,
      color: color,
    );
  }

  static Widget error(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'xmark.circle',
      materialIcon: Icons.error_outline,
      cupertinoIcon: CupertinoIcons.xmark_circle,
      size: size,
      color: color,
    );
  }

  static Widget success(BuildContext context, {double? size, Color? color}) {
    return adaptive(
      context,
      sfSymbol: 'checkmark.circle',
      materialIcon: Icons.check_circle_outline,
      cupertinoIcon: CupertinoIcons.checkmark_circle,
      size: size,
      color: color,
    );
  }
}
