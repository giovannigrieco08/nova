/// Animated search result wrapper
///
/// Provides staggered fade-in animation for search results.
/// Uses SlideTransition with FadeTransition for smooth 60fps performance.
library;

import 'package:flutter/material.dart';

/// Widget that animates search result items with staggered fade-in
class AnimatedSearchResult extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;
  final Duration animationDuration;

  const AnimatedSearchResult({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedSearchResult> createState() => _AnimatedSearchResultState();
}

class _AnimatedSearchResultState extends State<AnimatedSearchResult>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Start animation after stagger delay
    Future.delayed(widget.staggerDelay * widget.index, () {
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
