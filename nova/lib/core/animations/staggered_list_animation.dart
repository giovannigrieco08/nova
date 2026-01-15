import 'package:flutter/material.dart';

/// A widget that animates its child with a staggered fade + slide effect.
///
/// Perfect for list items that should animate in sequence when the list loads.
/// Each item delays based on its [index] to create a cascade effect.
///
/// Usage:
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) {
///     return StaggeredListItem(
///       index: index,
///       child: MyListTile(item: items[index]),
///     );
///   },
/// )
/// ```
class StaggeredListItem extends StatefulWidget {
  /// The widget to animate.
  final Widget child;

  /// The index of this item in the list (used to calculate stagger delay).
  final int index;

  /// Delay between each item's animation start.
  /// Default: 50ms creates smooth cascading effect.
  final Duration staggerDelay;

  /// Duration of the animation.
  /// Default: 400ms for natural feel.
  final Duration duration;

  /// How far the item slides up from. 0.0 = no slide, 1.0 = full height.
  /// Default: 0.1 (10% of parent height).
  final double slideOffset;

  /// Whether to animate. Set to false to disable animation.
  final bool animate;

  /// Maximum items to animate (items beyond this appear instantly).
  /// Helps performance with long lists.
  final int maxAnimatedItems;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 200),
    this.slideOffset = 0.05,
    this.animate = true,
    this.maxAnimatedItems = 8,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Only animate first N items for performance
    if (widget.animate && widget.index < widget.maxAnimatedItems) {
      _startAnimation();
    } else {
      // Show immediately if animation disabled or beyond limit
      _controller.value = 1.0;
    }
  }

  void _startAnimation() {
    final delay = widget.staggerDelay * widget.index;
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Controller for manually triggering staggered animations.
///
/// Useful when you need to re-animate items (e.g., after refresh).
///
/// Usage:
/// ```dart
/// final staggerController = StaggeredAnimationController();
///
/// // In your widget:
/// StaggeredListItem(
///   index: index,
///   controller: staggerController,
///   child: MyWidget(),
/// )
///
/// // Trigger re-animation:
/// staggerController.reset();
/// staggerController.animate();
/// ```
class StaggeredAnimationController extends ChangeNotifier {
  bool _shouldAnimate = true;

  bool get shouldAnimate => _shouldAnimate;

  void reset() {
    _shouldAnimate = false;
    notifyListeners();
  }

  void animate() {
    _shouldAnimate = true;
    notifyListeners();
  }
}

/// Extension to create staggered animation on any list.
///
/// Usage:
/// ```dart
/// items.mapIndexed((index, item) => StaggeredListItem(
///   index: index,
///   child: ItemWidget(item: item),
/// )).toList()
/// ```
extension StaggeredListExtension<T> on List<T> {
  /// Maps list items with their index for staggered animation.
  List<Widget> toStaggeredList({
    required Widget Function(int index, T item) builder,
    Duration staggerDelay = const Duration(milliseconds: 30),
    Duration duration = const Duration(milliseconds: 200),
    bool animate = true,
  }) {
    return asMap().entries.map((entry) {
      return StaggeredListItem(
        index: entry.key,
        staggerDelay: staggerDelay,
        duration: duration,
        animate: animate,
        child: builder(entry.key, entry.value),
      );
    }).toList();
  }
}
