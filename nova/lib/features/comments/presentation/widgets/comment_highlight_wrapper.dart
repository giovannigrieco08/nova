import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../providers/realtime_comments_provider.dart';

/// CommentHighlightWrapper Widget
///
/// Wraps a comment card and applies a highlight animation
/// when the comment is newly added via real-time updates.
///
/// **T090**: Visual feedback for realtime updates
///
/// Animation:
/// - Fade-in: 0 → 1 opacity over 300ms
/// - Background flash: Primary color at 20% opacity, fading to transparent
/// - Duration: 1 second total
///
/// Usage:
/// ```dart
/// CommentHighlightWrapper(
///   eventId: eventId,
///   commentId: comment.id,
///   child: CommentCard(comment: comment),
/// )
/// ```
class CommentHighlightWrapper extends ConsumerStatefulWidget {
  final String eventId;
  final String commentId;
  final Widget child;

  const CommentHighlightWrapper({
    super.key,
    required this.eventId,
    required this.commentId,
    required this.child,
  });

  @override
  ConsumerState<CommentHighlightWrapper> createState() =>
      _CommentHighlightWrapperState();
}

class _CommentHighlightWrapperState
    extends ConsumerState<CommentHighlightWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _colorAnimation;

  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _colorAnimation = ColorTween(
      begin: NovaColors.primaryLight.withValues(alpha: 0.2),
      end: Colors.transparent,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final realtimeNotifier =
        ref.watch(realtimeCommentsProvider(widget.eventId).notifier);
    final isNewlyAdded = realtimeNotifier.isNewlyAdded(widget.commentId);

    // Start animation when comment is newly added
    if (isNewlyAdded && !_hasAnimated) {
      _hasAnimated = true;
      _controller.forward();
    }

    // If not newly added and never animated, show without animation
    if (!isNewlyAdded && !_hasAnimated) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _hasAnimated ? _fadeAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: _colorAnimation.value,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Simple highlight decoration for newly added comments
///
/// A simpler alternative that just adds a colored left border
class NewCommentIndicator extends StatelessWidget {
  final bool isNew;
  final Widget child;

  const NewCommentIndicator({
    super.key,
    required this.isNew,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isNew) return child;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: NovaColors.primaryLight,
            width: 3,
          ),
        ),
      ),
      child: child,
    );
  }
}
