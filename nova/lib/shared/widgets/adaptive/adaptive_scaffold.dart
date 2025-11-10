import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive scaffold that renders native components.
///
/// - iOS: [CupertinoPageScaffold]
/// - Android: [Scaffold]
///
/// Example:
/// ```dart
/// AdaptiveScaffold(
///   appBar: AdaptiveAppBar(title: Text('Home')),
///   body: MyContent(),
///   bottomNavigationBar: AdaptiveBottomNavBar(...),
/// )
/// ```
class AdaptiveScaffold extends StatelessWidget {
  /// App bar widget (must be [PreferredSizeWidget])
  final PreferredSizeWidget? appBar;

  /// Primary content of the scaffold
  final Widget? body;

  /// Bottom navigation bar (Android only, iOS uses CupertinoTabScaffold instead)
  final Widget? bottomNavigationBar;

  /// Floating action button (Android only)
  final Widget? floatingActionButton;

  /// Background color
  final Color? backgroundColor;

  /// Whether body should avoid system UI (safe area)
  final bool avoidSystemUI;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.avoidSystemUI = true,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      // iOS: CupertinoPageScaffold
      return CupertinoPageScaffold(
        navigationBar: appBar as ObstructingPreferredSizeWidget?,
        backgroundColor: backgroundColor,
        child: body ?? const SizedBox.shrink(),
      );
    }

    // Android: Material Scaffold
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
    );
  }
}
