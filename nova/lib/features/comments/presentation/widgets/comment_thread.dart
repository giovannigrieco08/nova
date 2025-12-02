import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';
import '../providers/replies_provider.dart';
import 'comment_card.dart';

/// CommentThread Widget
///
/// Displays a parent comment with its replies in threaded view.
///
/// Layout:
/// - Parent comment (full width)
/// - Replies indented 48px to the left with vertical line connector
/// - Visual thread hierarchy with purple connector line
///
/// Features:
/// - Automatic reply loading via GetRepliesForComment use case
/// - Collapse/expand functionality with smooth animation (T058)
/// - Default collapse if >3 replies
/// - Vertical line connector showing thread continuity
/// - 48px left indent for replies (Instagram-style threading)
///
/// **FR-031**: Students can reply to comments (1-level threading)
/// **FR-032**: Replies display indented under parent comment
///
/// Usage:
/// ```dart
/// CommentThread(
///   parentComment: comment,
///   eventId: '123',
/// )
/// ```
class CommentThread extends ConsumerStatefulWidget {
  final Comment parentComment;
  final String eventId;

  const CommentThread({
    super.key,
    required this.parentComment,
    required this.eventId,
  });

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = true; // Default value, updated in initState based on reply count

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Default collapse if >3 replies (T058 requirement)
    // We'll check this when replies are loaded
    if (widget.parentComment.replyCount > 3) {
      _isExpanded = false;
      _animationController.value = 0.0;
    } else {
      _isExpanded = true;
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fetch replies for this parent comment
    final repliesAsync = ref.watch(
      repliesProviderFamily(widget.parentComment.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent comment
        CommentCard(
          comment: widget.parentComment,
          eventId: widget.eventId,
        ),

        // Replies section
        repliesAsync.when(
          data: (replies) {
            if (replies.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expansion toggle button (only if has replies)
                _buildExpansionToggle(replies.length),

                // Animated replies list
                SizeTransition(
                  sizeFactor: _animation,
                  child: Column(
                    children: replies.map((reply) {
                      return _buildReplyWithConnector(context, reply);
                    }).toList(),
                  ),
                ),
              ],
            );
          },
          loading: () => Padding(
            padding: EdgeInsets.only(left: NovaSpacing.xxxxl),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NovaColors.primary(context),
                ),
              ),
            ),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Builds the expansion toggle button
  Widget _buildExpansionToggle(int replyCount) {
    return Semantics(
      button: true,
      label: _isExpanded
          ? 'Nascondi $replyCount ${replyCount == 1 ? "risposta" : "risposte"}'
          : 'Mostra $replyCount ${replyCount == 1 ? "risposta" : "risposte"}',
      child: GestureDetector(
        onTap: _toggleExpansion,
        child: Padding(
          padding: EdgeInsets.only(
            left: NovaSpacing.m + 40 + NovaSpacing.s, // Avatar width + spacing
            top: NovaSpacing.xs,
            bottom: NovaSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated chevron icon
              AnimatedRotation(
                turns: _isExpanded ? 0.25 : 0.0, // 90 degrees when expanded
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: NovaColors.primaryLight,
                ),
              ),
              SizedBox(width: NovaSpacing.xxs),
              Text(
                _isExpanded
                    ? 'Nascondi ${replyCount == 1 ? "risposta" : "risposte"}'
                    : 'Mostra $replyCount ${replyCount == 1 ? "risposta" : "risposte"}',
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a reply with vertical line connector
  Widget _buildReplyWithConnector(BuildContext context, Comment reply) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical line connector + indent
        SizedBox(
          width: 48, // 48px indent per task spec
          child: CustomPaint(
            painter: _ThreadConnectorPainter(
              color: NovaColors.primary(context).withOpacity(0.3),
            ),
            child: const SizedBox(width: 48, height: double.infinity),
          ),
        ),

        // Reply comment
        Expanded(
          child: CommentCard(
            comment: reply,
            eventId: widget.eventId,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for vertical thread connector line
class _ThreadConnectorPainter extends CustomPainter {
  final Color color;

  _ThreadConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw vertical line from top to middle-left
    // Line starts 24px from left (center of 48px indent zone)
    // and goes down the full height
    const double lineX = 24.0; // Center of 48px indent

    // Vertical line
    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      paint,
    );

    // Horizontal connector to comment (small hook)
    // Starts at vertical line, extends 12px to the right
    canvas.drawLine(
      Offset(lineX, size.height * 0.5),
      Offset(lineX + 12, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ThreadConnectorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
