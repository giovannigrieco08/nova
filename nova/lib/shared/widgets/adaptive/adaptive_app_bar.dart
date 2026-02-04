import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Platform-adaptive app bar with iOS large title support.
///
/// - iOS: [CupertinoNavigationBar] or [CupertinoSliverNavigationBar] (with large title)
/// - Android: [AppBar]
///
/// Example (standard):
/// ```dart
/// AdaptiveAppBar(
///   title: Text('Home'),
///   actions: [IconButton(...)],
/// )
/// ```
///
/// Example (iOS large title - use in CustomScrollView):
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverToBoxAdapter(
///       child: AdaptiveAppBar(
///         title: Text('Events'),
///         large: true,
///       ),
///     ),
///     SliverList(...),
///   ],
/// )
/// ```
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Leading widget (usually back button or menu)
  final Widget? leading;

  /// App bar title
  final Widget? title;

  /// Trailing actions
  final List<Widget>? actions;

  /// iOS only: Enable large title (requires CustomScrollView with slivers)
  final bool large;

  /// iOS only: Show previous page title in back button
  final String? previousPageTitle;

  /// Background color
  final Color? backgroundColor;

  const AdaptiveAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.large = false,
    this.previousPageTitle,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(large ? 96 : 60);

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      if (large) {
        // iOS Large Title (for use in CustomScrollView)
        return CupertinoSliverNavigationBar(
          leading: leading,
          largeTitle: title ?? const SizedBox.shrink(),
          trailing: actions != null && actions!.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                )
              : null,
          backgroundColor: backgroundColor ??
              NovaColors.background(context).withValues(alpha: 0.9),
          border: null,
        );
      }

      // iOS Standard Navigation Bar
      return CupertinoNavigationBar(
        leading: leading,
        middle: title,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        backgroundColor: backgroundColor ??
            NovaColors.background(context).withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: NovaColors.border(context),
            width: 0.5,
          ),
        ),
        previousPageTitle: previousPageTitle,
      );
    }

    // Android: Material AppBar
    return AppBar(
      leading: leading,
      title: title,
      actions: actions,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: backgroundColor ?? NovaColors.background(context),
      surfaceTintColor: Colors.transparent,
    );
  }
}
