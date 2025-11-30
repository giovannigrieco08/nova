import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';

/// CommentActionsMenu Widget
///
/// Platform-adaptive context menu for comment actions.
///
/// Platform Behavior:
/// - Android: Long-press to show menu
/// - iOS: Swipe-left to reveal actions or long-press
///
/// Actions:
/// - 💬 Rispondi (top-level comments only)
/// - 🚩 Segnala
/// - 📋 Copia testo
/// - 🗑️ Elimina (own comments only)
/// - ✏️ Modifica (own comments within 5min)
///
/// **T063**: Create CommentActionsMenu widget
/// **FR-033**: Students can report comments
/// **FR-036**: Students can delete own comments
///
/// Usage:
/// ```dart
/// CommentActionsMenu(
///   comment: comment,
///   currentUserId: currentUserId,
///   onReply: () => startReply(comment),
///   onReport: () => showReportDialog(),
///   onCopy: () => copyToClipboard(),
///   onDelete: () => deleteComment(),
///   onEdit: () => editComment(),
///   child: CommentCard(comment: comment),
/// )
/// ```
class CommentActionsMenu extends StatelessWidget {
  final Comment comment;
  final String? currentUserId;
  final VoidCallback? onReply;
  final VoidCallback? onReport;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final Widget child;

  const CommentActionsMenu({
    super.key,
    required this.comment,
    this.currentUserId,
    this.onReply,
    this.onReport,
    this.onCopy,
    this.onDelete,
    this.onEdit,
    required this.child,
  });

  bool get _isOwnComment => currentUserId != null && comment.userId == currentUserId;
  bool get _canEdit => _isOwnComment && comment.canEdit(DateTime.now());
  bool get _canDelete => _isOwnComment && !comment.isDeleted;
  bool get _canReply => comment.isTopLevel && !comment.isDeleted;
  bool get _canReport => !_isOwnComment && !comment.isDeleted;
  bool get _canCopy => !comment.isDeleted;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSMenu(context);
    }
    return _buildAndroidMenu(context);
  }

  Widget _buildAndroidMenu(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showAndroidMenu(context),
      child: child,
    );
  }

  Widget _buildIOSMenu(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showIOSActionSheet(context),
      child: child,
    );
  }

  void _showAndroidMenu(BuildContext context) {
    final actions = _buildActions();
    if (actions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: NovaSpacing.s),
              decoration: BoxDecoration(
                color: NovaColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Actions list
            ...actions.map((action) {
              return ListTile(
                leading: Icon(
                  action.icon,
                  color: action.isDestructive ? NovaColors.error(context) : null,
                ),
                title: Text(
                  action.label,
                  style: NovaTypography.bodyMedium.copyWith(
                    color: action.isDestructive ? NovaColors.error(context) : null,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  action.onTap();
                },
              );
            }),

            SizedBox(height: NovaSpacing.m),
          ],
        ),
      ),
    );
  }

  void _showIOSActionSheet(BuildContext context) {
    final actions = _buildActions();
    if (actions.isEmpty) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: actions.map((action) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              action.onTap();
            },
            isDestructiveAction: action.isDestructive,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action.icon,
                  size: 20,
                  color: action.isDestructive
                      ? CupertinoColors.destructiveRed
                      : CupertinoColors.activeBlue,
                ),
                SizedBox(width: NovaSpacing.s),
                Text(action.label),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ),
    );
  }

  List<_CommentAction> _buildActions() {
    final actions = <_CommentAction>[];

    if (_canReply && onReply != null) {
      actions.add(_CommentAction(
        icon: Icons.reply,
        label: '💬 Rispondi',
        onTap: onReply!,
      ));
    }

    if (_canCopy && onCopy != null) {
      actions.add(_CommentAction(
        icon: Icons.copy,
        label: '📋 Copia testo',
        onTap: onCopy!,
      ));
    }

    if (_canEdit && onEdit != null) {
      actions.add(_CommentAction(
        icon: Icons.edit,
        label: '✏️ Modifica',
        onTap: onEdit!,
      ));
    }

    if (_canReport && onReport != null) {
      actions.add(_CommentAction(
        icon: Icons.flag_outlined,
        label: '🚩 Segnala',
        onTap: onReport!,
      ));
    }

    if (_canDelete && onDelete != null) {
      actions.add(_CommentAction(
        icon: Icons.delete_outline,
        label: '🗑️ Elimina',
        onTap: onDelete!,
        isDestructive: true,
      ));
    }

    return actions;
  }
}

class _CommentAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  _CommentAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// Copy comment text to clipboard
///
/// Shows platform-adaptive feedback message.
Future<void> copyCommentToClipboard(BuildContext context, Comment comment) async {
  await Clipboard.setData(ClipboardData(text: comment.displayText));

  if (context.mounted) {
    if (Platform.isIOS) {
      // iOS doesn't need explicit feedback - system provides it
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Testo copiato',
            style: NovaTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
