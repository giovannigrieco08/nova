import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'swipe_back_page_route.dart';

/// Nova page transition utilities.
///
/// Provides consistent page transitions across the app with iOS-style
/// and custom animations.

/// Transition direction for slide animations.
enum SlideDirection {
  /// Slide from left to right (e.g., creation screens).
  fromLeft,

  /// Slide from right to left (e.g., detail screens).
  fromRight,

  /// Slide from bottom to top (e.g., modals).
  fromBottom,

  /// Slide from top to bottom (e.g., dropdowns).
  fromTop,
}

/// Creates a page route with slide transition.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   NovaPageRoute.slide(
///     page: const DetailScreen(),
///     direction: SlideDirection.fromRight,
///   ),
/// );
/// ```
class NovaPageRoute {
  /// Creates a slide transition route.
  static PageRouteBuilder<T> slide<T>({
    required Widget page,
    SlideDirection direction = SlideDirection.fromRight,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    bool opaque = true,
    bool barrierDismissible = false,
    Color? barrierColor,
    String? barrierLabel,
    bool maintainState = true,
    bool fullscreenDialog = false,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final begin = _getBeginOffset(direction);
        const end = Offset.zero;

        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      opaque: opaque,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      settings: settings,
    );
  }

  /// Creates a fade transition route.
  static PageRouteBuilder<T> fade<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: curve)),
          child: child,
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      settings: settings,
    );
  }

  /// Creates a scale + fade transition (zoom effect).
  static PageRouteBuilder<T> scale<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
    double beginScale = 0.9,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: beginScale, end: 1.0)
                .animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      settings: settings,
    );
  }

  /// Creates a slide + fade transition.
  static PageRouteBuilder<T> slideAndFade<T>({
    required Widget page,
    SlideDirection direction = SlideDirection.fromBottom,
    Duration duration = const Duration(milliseconds: 350),
    Duration reverseDuration = const Duration(milliseconds: 350),
    Curve curve = Curves.easeOutCubic,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        final begin = _getBeginOffset(direction) * 0.3; // Subtle slide
        const end = Offset.zero;

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween(begin: begin, end: end).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      settings: settings,
    );
  }

  /// Creates an iOS-style push transition.
  static Route<T> ios<T>({
    required Widget page,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return CupertinoPageRoute<T>(
      builder: (context) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }

  /// Creates a Material Design push transition.
  static Route<T> material<T>({
    required Widget page,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return MaterialPageRoute<T>(
      builder: (context) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }

  /// Creates a platform-appropriate transition (iOS or Material).
  static Route<T> adaptive<T>({
    required Widget page,
    required BuildContext context,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return isIOS
        ? ios<T>(
            page: page,
            settings: settings,
            fullscreenDialog: fullscreenDialog,
            maintainState: maintainState,
          )
        : material<T>(
            page: page,
            settings: settings,
            fullscreenDialog: fullscreenDialog,
            maintainState: maintainState,
          );
  }

  /// Creates a route with swipe-to-go-back gesture support.
  ///
  /// On iOS, uses native CupertinoPageRoute with built-in swipe gesture.
  /// On Android, uses custom SwipeBackPageRoute that adds swipe-from-left-edge.
  ///
  /// Usage:
  /// ```dart
  /// Navigator.push(
  ///   context,
  ///   NovaPageRoute.swipeBack(page: DetailScreen()),
  /// );
  /// ```
  static Route<T> swipeBack<T>({
    required Widget page,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    if (Platform.isIOS) {
      return CupertinoPageRoute<T>(
        builder: (_) => page,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
        maintainState: maintainState,
      );
    }
    return SwipeBackPageRoute<T>(
      builder: (_) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }

  /// Creates a route with swipe-to-go-back gesture from the RIGHT edge.
  ///
  /// Use this for screens that slide in from the LEFT (like creation screens).
  /// Users swipe from right-to-left to dismiss.
  ///
  /// Usage:
  /// ```dart
  /// Navigator.push(
  ///   context,
  ///   NovaPageRoute.swipeBackFromRight(page: CreateScreen()),
  /// );
  /// ```
  static Route<T> swipeBackFromRight<T>({
    required Widget page,
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    return SwipeBackRightPageRoute<T>(
      builder: (_) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }

  static Offset _getBeginOffset(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.fromLeft:
        return const Offset(-1.0, 0.0);
      case SlideDirection.fromRight:
        return const Offset(1.0, 0.0);
      case SlideDirection.fromBottom:
        return const Offset(0.0, 1.0);
      case SlideDirection.fromTop:
        return const Offset(0.0, -1.0);
    }
  }
}

/// Extension methods for easy navigation with transitions.
extension NovaNavigator on NavigatorState {
  /// Push with slide from left transition.
  Future<T?> pushSlideFromLeft<T extends Object?>(Widget page) {
    return push(NovaPageRoute.slide(
      page: page,
      direction: SlideDirection.fromLeft,
    ));
  }

  /// Push with slide from right transition.
  Future<T?> pushSlideFromRight<T extends Object?>(Widget page) {
    return push(NovaPageRoute.slide(
      page: page,
      direction: SlideDirection.fromRight,
    ));
  }

  /// Push with slide from bottom transition.
  Future<T?> pushSlideFromBottom<T extends Object?>(Widget page) {
    return push(NovaPageRoute.slide(
      page: page,
      direction: SlideDirection.fromBottom,
    ));
  }

  /// Push with fade transition.
  Future<T?> pushFade<T extends Object?>(Widget page) {
    return push(NovaPageRoute.fade(page: page));
  }

  /// Push with scale transition.
  Future<T?> pushScale<T extends Object?>(Widget page) {
    return push(NovaPageRoute.scale(page: page));
  }
}
