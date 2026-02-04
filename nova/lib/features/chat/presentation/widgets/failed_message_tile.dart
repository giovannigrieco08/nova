import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';

/// A tile showing a message that failed to send.
///
/// Features:
/// - Red error indicator
/// - Message preview
/// - Retry button
/// - Dismiss (swipe to delete) option
class FailedMessageTile extends ConsumerStatefulWidget {
  final FailedMessage failedMessage;

  const FailedMessageTile({
    super.key,
    required this.failedMessage,
  });

  @override
  ConsumerState<FailedMessageTile> createState() => _FailedMessageTileState();
}

class _FailedMessageTileState extends ConsumerState<FailedMessageTile> {
  bool _isRetrying = false;

  Future<void> _retryMessage() async {
    setState(() => _isRetrying = true);

    final success = await ref
        .read(failedMessagesProvider.notifier)
        .retryMessage(widget.failedMessage.id);

    if (mounted) {
      setState(() => _isRetrying = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Messaggio inviato'),
            backgroundColor: NovaColors.success(context),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invio fallito. Riprova.'),
            backgroundColor: NovaColors.error(context),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _dismissMessage() {
    ref
        .read(failedMessagesProvider.notifier)
        .removeFailedMessage(widget.failedMessage.id);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('failed_${widget.failedMessage.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismissMessage(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: NovaSpacing.m),
        color: NovaColors.error(context).withValues(alpha: 0.2),
        child: Icon(
          Icons.delete_outline,
          color: NovaColors.error(context),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Error indicator
            Padding(
              padding: EdgeInsets.only(right: NovaSpacing.xs, bottom: 4),
              child: Icon(
                Icons.error_outline,
                color: NovaColors.error(context),
                size: 16,
              ),
            ),

            // Message bubble
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.m + 4,
                  vertical: NovaSpacing.s + 2,
                ),
                decoration: BoxDecoration(
                  color: NovaColors.error(context).withValues(alpha: 0.15),
                  borderRadius: NovaRadius.circularL,
                  border: Border.all(
                    color: NovaColors.error(context).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Message content
                    Text(
                      widget.failedMessage.content,
                      style: NovaTypography.bodyMedium.copyWith(
                        color: NovaColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: NovaSpacing.xs),

                    // Error message + retry button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            'Invio fallito',
                            style: NovaTypography.bodySmall.copyWith(
                              color: NovaColors.error(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Retry button
                        GestureDetector(
                          onTap: _isRetrying ? null : _retryMessage,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: NovaSpacing.s,
                              vertical: NovaSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: NovaColors.error(context),
                              borderRadius: NovaRadius.circularXs,
                            ),
                            child: _isRetrying
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NovaColors.onErrorLight,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh,
                                        size: 14,
                                        color: NovaColors.onErrorLight,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Riprova',
                                        style:
                                            NovaTypography.bodySmall.copyWith(
                                          color: NovaColors.onErrorLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
