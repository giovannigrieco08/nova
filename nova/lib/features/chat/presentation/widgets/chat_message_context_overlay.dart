import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Instagram DM-style context menu overlay for chat messages.
///
/// Shows:
/// - Blurred background
/// - Message bubble centered
/// - Emoji reactions pill floating above message
/// - Action menu below message (Rispondi, Copia, Elimina, etc.)
class ChatMessageContextOverlay extends StatefulWidget {
  /// The message bubble widget to display
  final Widget messageBubble;

  /// Whether this is the current user's message
  final bool isOwnMessage;

  /// Current user's reactions to this message
  final Set<String> currentUserReactions;

  /// Callback when user taps an emoji reaction
  final void Function(String emoji)? onReact;

  /// Callback when user taps Reply
  final VoidCallback? onReply;

  /// Callback when user taps Copy
  final VoidCallback? onCopy;

  /// Callback when user taps Delete
  final VoidCallback? onDelete;

  /// Callback when user taps Report
  final VoidCallback? onReport;

  /// Callback when user taps Edit
  final VoidCallback? onEdit;

  /// The message content for copying
  final String? messageContent;

  /// Whether the message can be edited (within 15-min window)
  final bool canEdit;

  const ChatMessageContextOverlay({
    super.key,
    required this.messageBubble,
    required this.isOwnMessage,
    this.currentUserReactions = const {},
    this.onReact,
    this.onReply,
    this.onCopy,
    this.onDelete,
    this.onReport,
    this.onEdit,
    this.messageContent,
    this.canEdit = false,
  });

  /// Show the context overlay as a modal route
  static Future<void> show(
    BuildContext context, {
    required Widget messageBubble,
    required bool isOwnMessage,
    Set<String> currentUserReactions = const {},
    void Function(String emoji)? onReact,
    VoidCallback? onReply,
    VoidCallback? onCopy,
    VoidCallback? onDelete,
    VoidCallback? onReport,
    VoidCallback? onEdit,
    String? messageContent,
    bool canEdit = false,
  }) {
    // Haptic feedback on open
    HapticFeedback.mediumImpact();

    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ChatMessageContextOverlay(
            messageBubble: messageBubble,
            isOwnMessage: isOwnMessage,
            currentUserReactions: currentUserReactions,
            onReact: onReact,
            onReply: onReply,
            onCopy: onCopy,
            onDelete: onDelete,
            onReport: onReport,
            onEdit: onEdit,
            messageContent: messageContent,
            canEdit: canEdit,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Fast, snappy transition with combined fade and scale
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 100),
        reverseTransitionDuration: const Duration(milliseconds: 80),
      ),
    );
  }

  @override
  State<ChatMessageContextOverlay> createState() =>
      _ChatMessageContextOverlayState();
}

class _ChatMessageContextOverlayState extends State<ChatMessageContextOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  /// Allowed emoji reactions (matches database constraint)
  static const List<String> _allowedEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    // Start from 0.95 for a subtler but snappier scale effect
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _handleReaction(String emoji) {
    _close();
    widget.onReact?.call(emoji);
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: 350,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              Navigator.pop(sheetContext);
              _handleReaction(emoji.emoji);
            },
            config: Config(
              height: 350,
              checkPlatformCompatibility: true,
              viewOrderConfig: const ViewOrderConfig(),
              emojiViewConfig: EmojiViewConfig(
                emojiSizeMax: 28,
                backgroundColor: NovaColors.surface(context),
              ),
              skinToneConfig: const SkinToneConfig(),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: NovaColors.surface(context),
                indicatorColor: NovaColors.primary(context),
                iconColorSelected: NovaColors.primary(context),
                iconColor: NovaColors.textSecondary(context),
              ),
              bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
              searchViewConfig: SearchViewConfig(
                backgroundColor: NovaColors.surface(context),
                buttonIconColor: NovaColors.textSecondary(context),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleReply() {
    _close();
    widget.onReply?.call();
  }

  void _handleCopy() {
    _close();
    if (widget.messageContent != null && widget.messageContent!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: widget.messageContent!));
      // Show snackbar feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Messaggio copiato'),
          duration: const Duration(seconds: 2),
          backgroundColor: NovaColors.textSecondary(context),
        ),
      );
    }
    widget.onCopy?.call();
  }

  void _handleDelete() {
    _close();
    widget.onDelete?.call();
  }

  void _handleReport() {
    _close();
    widget.onReport?.call();
  }

  void _handleEdit() {
    _close();
    widget.onEdit?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Content (message + reactions + actions)
          SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent tap-through to dismiss
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Emoji reactions pill (above message)
                      _buildReactionsPill(context),
                      SizedBox(height: NovaSpacing.s),

                      // Message bubble
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
                        child: widget.messageBubble,
                      ),
                      SizedBox(height: NovaSpacing.s),

                      // Action menu (below message)
                      _buildActionMenu(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the horizontal emoji reactions pill
  Widget _buildReactionsPill(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._allowedEmojis.map((emoji) {
            final hasReacted = widget.currentUserReactions.contains(emoji);
            return GestureDetector(
              onTap: () => _handleReaction(emoji),
              child: Container(
                width: 44,
                height: 44,
                margin: EdgeInsets.symmetric(horizontal: NovaSpacing.xxs),
                decoration: BoxDecoration(
                  color: hasReacted
                      ? NovaColors.primary(context).withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: hasReacted
                      ? Border.all(
                          color: NovaColors.primary(context),
                          width: 2,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 24,
                      decoration: TextDecoration.none,
                      color: NovaColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            );
          }),
          // Plus button for more emojis
          GestureDetector(
            onTap: _showEmojiPicker,
            child: Container(
              width: 44,
              height: 44,
              margin: EdgeInsets.only(left: NovaSpacing.xs),
              decoration: BoxDecoration(
                color: NovaColors.card(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: NovaColors.textSecondary(context),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the action menu below message
  Widget _buildActionMenu(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.l),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply
          _buildActionItem(
            context: context,
            icon: Icons.reply,
            label: 'Rispondi',
            onTap: _handleReply,
          ),

          _buildDivider(context),

          // Copy (only for text messages)
          if (widget.messageContent != null &&
              widget.messageContent!.isNotEmpty) ...[
            _buildActionItem(
              context: context,
              icon: Icons.copy_outlined,
              label: 'Copia',
              onTap: _handleCopy,
            ),
            _buildDivider(context),
          ],

          // Edit (only for own messages within 15-minute window)
          if (widget.isOwnMessage && widget.canEdit && widget.onEdit != null) ...[
            _buildActionItem(
              context: context,
              icon: Icons.edit_outlined,
              label: 'Modifica',
              onTap: _handleEdit,
            ),
            _buildDivider(context),
          ],

          // Report (only for others' messages)
          if (!widget.isOwnMessage) ...[
            _buildActionItem(
              context: context,
              icon: Icons.flag_outlined,
              label: 'Segnala',
              onTap: _handleReport,
              isDestructive: true,
            ),
          ],

          // Delete (only for own messages within 30-minute window)
          if (widget.onDelete != null) ...[
            _buildActionItem(
              context: context,
              icon: Icons.delete_outline,
              label: 'Elimina',
              onTap: _handleDelete,
              isDestructive: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? NovaColors.error(context)
        : NovaColors.textPrimary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NovaRadius.l),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.m,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(width: NovaSpacing.m),
              Text(
                label,
                style: NovaTypography.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: NovaColors.divider(context),
      indent: NovaSpacing.m,
      endIndent: NovaSpacing.m,
    );
  }
}
