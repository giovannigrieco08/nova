import 'dart:io';
import 'package:flutter/cupertino.dart';

/// A page route that supports swipe-to-go-back gesture on Android.
///
/// On iOS, this uses the native CupertinoPageRoute which already has
/// swipe-back support. On Android, it wraps the page with a custom
/// gesture detector that enables swipe-from-left-edge to go back.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   SwipeBackPageRoute(builder: (_) => DetailScreen()),
/// );
/// ```
class SwipeBackPageRoute<T> extends PageRoute<T> {
  SwipeBackPageRoute({
    required this.builder,
    this.maintainState = true,
    super.settings,
    bool fullscreenDialog = false,
  }) : _fullscreenDialog = fullscreenDialog;

  /// Builds the page content.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  final bool _fullscreenDialog;

  @override
  bool get fullscreenDialog => _fullscreenDialog;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  /// Width of the area from the left edge where the gesture is detected.
  /// Increased from 20 to 30 for easier swipe-to-go-back gesture.
  static const double _kEdgeWidth = 30.0;

  /// The minimum velocity to trigger a pop (pixels per second).
  static const double _kMinFlingVelocity = 300.0;

  /// The threshold (0.0 to 1.0) of screen width to trigger pop on release.
  static const double _kPopThreshold = 0.3;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // On iOS, use native Cupertino transitions with built-in swipe back
    if (Platform.isIOS) {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: isPopGestureInProgress,
        child: child,
      );
    }

    // On Android, wrap with our custom swipe-back gesture detector
    return _SwipeBackGestureDetector(
      route: this,
      animation: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: child,
      ),
    );
  }

  /// Whether a pop gesture is currently in progress.
  bool get isPopGestureInProgress => navigator?.userGestureInProgress ?? false;

  /// Whether the pop gesture can start.
  @override
  bool get popGestureEnabled {
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (!hasActiveRouteBelow) return false;
    if (isPopGestureInProgress) return false;
    return true;
  }

  /// Check if animation is completed (safe null check)
  bool isAnimationCompleted(Animation<double> animation) {
    return animation.status == AnimationStatus.completed;
  }
}

/// Gesture detector for swipe-back functionality.
class _SwipeBackGestureDetector extends StatefulWidget {
  const _SwipeBackGestureDetector({
    required this.route,
    required this.animation,
    required this.child,
  });

  final SwipeBackPageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_SwipeBackGestureDetector> createState() =>
      _SwipeBackGestureDetectorState();
}

class _SwipeBackGestureDetectorState extends State<_SwipeBackGestureDetector> {
  _SwipeBackGestureController? _gestureController;

  bool get _canStartGesture {
    return widget.route.popGestureEnabled &&
        widget.route.isAnimationCompleted(widget.animation);
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_canStartGesture) return;
    if (widget.route.navigator == null) return;

    // Get the animation controller from the route's animation
    final animation = widget.animation;
    if (animation is! AnimationController) return;

    _gestureController = _SwipeBackGestureController(
      navigator: widget.route.navigator!,
      controller: animation,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _gestureController?.dragUpdate(
      details.primaryDelta! / context.size!.width,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    _gestureController?.dragEnd(
      details.velocity.pixelsPerSecond.dx / context.size!.width,
    );
    _gestureController = null;
  }

  void _handleDragCancel() {
    _gestureController?.dragEnd(0.0);
    _gestureController = null;
  }

  @override
  Widget build(BuildContext context) {
    // Use a stack to overlay the gesture area on the left edge
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Gesture detection area on the left edge
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: SwipeBackPageRoute._kEdgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            onHorizontalDragCancel: _handleDragCancel,
          ),
        ),
      ],
    );
  }
}

/// Controller for the swipe-back gesture animation.
class _SwipeBackGestureController {
  _SwipeBackGestureController({
    required this.navigator,
    required this.controller,
  }) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;

  /// Updates the animation based on drag delta.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// Ends the gesture and decides whether to pop or animate back.
  void dragEnd(double velocity) {
    // Decide whether to pop based on velocity or position threshold
    final shouldPop = velocity > SwipeBackPageRoute._kMinFlingVelocity / 300 ||
        (velocity >= 0 &&
            controller.value < 1.0 - SwipeBackPageRoute._kPopThreshold);

    if (shouldPop) {
      navigator.pop();
    } else {
      // Animate back to fully visible
      controller.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }

    navigator.didStopUserGesture();
  }
}

// =============================================================================
// SwipeBackRightPageRoute - Swipe from RIGHT edge to go back
// =============================================================================

/// A page route that supports swipe-to-go-back gesture from the RIGHT edge.
///
/// This is the mirror of SwipeBackPageRoute, designed for screens that
/// slide in from the LEFT (like creation screens). Users swipe from
/// right-to-left to dismiss.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   SwipeBackRightPageRoute(builder: (_) => CreateScreen()),
/// );
/// ```
class SwipeBackRightPageRoute<T> extends PageRoute<T> {
  SwipeBackRightPageRoute({
    required this.builder,
    this.maintainState = true,
    super.settings,
    bool fullscreenDialog = false,
  }) : _fullscreenDialog = fullscreenDialog;

  /// Builds the page content.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  final bool _fullscreenDialog;

  @override
  bool get fullscreenDialog => _fullscreenDialog;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  /// Width of the area from the right edge where the gesture is detected.
  static const double _kEdgeWidth = 30.0;

  /// The minimum velocity to trigger a pop (pixels per second).
  static const double _kMinFlingVelocity = 300.0;

  /// The threshold (0.0 to 1.0) of screen width to trigger pop on release.
  static const double _kPopThreshold = 0.3;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // On iOS, use a mirrored Cupertino-style transition
    if (Platform.isIOS) {
      // Slide from left with right-edge gesture detection
      return _SwipeBackRightGestureDetector(
        route: this,
        animation: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0), // Slide from left
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )),
          child: child,
        ),
      );
    }

    // On Android, wrap with our custom swipe-back gesture detector
    return _SwipeBackRightGestureDetector(
      route: this,
      animation: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1.0, 0.0), // Slide from left
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: child,
      ),
    );
  }

  /// Whether a pop gesture is currently in progress.
  bool get isPopGestureInProgress => navigator?.userGestureInProgress ?? false;

  /// Whether the pop gesture can start.
  @override
  bool get popGestureEnabled {
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (!hasActiveRouteBelow) return false;
    if (isPopGestureInProgress) return false;
    return true;
  }

  /// Check if animation is completed (safe null check)
  bool isAnimationCompleted(Animation<double> animation) {
    return animation.status == AnimationStatus.completed;
  }
}

/// Gesture detector for swipe-back-from-right functionality.
class _SwipeBackRightGestureDetector extends StatefulWidget {
  const _SwipeBackRightGestureDetector({
    required this.route,
    required this.animation,
    required this.child,
  });

  final SwipeBackRightPageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_SwipeBackRightGestureDetector> createState() =>
      _SwipeBackRightGestureDetectorState();
}

class _SwipeBackRightGestureDetectorState
    extends State<_SwipeBackRightGestureDetector> {
  _SwipeBackRightGestureController? _gestureController;

  bool get _canStartGesture {
    return widget.route.popGestureEnabled &&
        widget.route.isAnimationCompleted(widget.animation);
  }

  void _handleDragStart(DragStartDetails details) {
    if (!_canStartGesture) return;
    if (widget.route.navigator == null) return;

    // Get the animation controller from the route's animation
    final animation = widget.animation;
    if (animation is! AnimationController) return;

    _gestureController = _SwipeBackRightGestureController(
      navigator: widget.route.navigator!,
      controller: animation,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Note: positive delta means dragging right, negative means left
    // For right-edge swipe, we want negative delta to trigger pop
    _gestureController?.dragUpdate(
      -details.primaryDelta! / context.size!.width, // Invert delta
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    _gestureController?.dragEnd(
      -details.velocity.pixelsPerSecond.dx /
          context.size!.width, // Invert velocity
    );
    _gestureController = null;
  }

  void _handleDragCancel() {
    _gestureController?.dragEnd(0.0);
    _gestureController = null;
  }

  @override
  Widget build(BuildContext context) {
    // Use a stack to overlay the gesture area on the right edge
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Gesture detection area on the right edge
        Positioned(
          right: 0, // Right edge instead of left
          top: 0,
          bottom: 0,
          width: SwipeBackRightPageRoute._kEdgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            onHorizontalDragCancel: _handleDragCancel,
          ),
        ),
      ],
    );
  }
}

/// Controller for the swipe-back-from-right gesture animation.
class _SwipeBackRightGestureController {
  _SwipeBackRightGestureController({
    required this.navigator,
    required this.controller,
  }) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;

  /// Updates the animation based on drag delta.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// Ends the gesture and decides whether to pop or animate back.
  void dragEnd(double velocity) {
    // Decide whether to pop based on velocity or position threshold
    final shouldPop = velocity >
            SwipeBackRightPageRoute._kMinFlingVelocity / 300 ||
        (velocity >= 0 &&
            controller.value < 1.0 - SwipeBackRightPageRoute._kPopThreshold);

    if (shouldPop) {
      navigator.pop();
    } else {
      // Animate back to fully visible
      controller.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }

    navigator.didStopUserGesture();
  }
}
