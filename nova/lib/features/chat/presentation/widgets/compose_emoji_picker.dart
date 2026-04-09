import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Wraps [EmojiPicker] with Nova's theme and styling.
class ComposeEmojiPicker extends StatelessWidget {
  final TextEditingController controller;

  const ComposeEmojiPicker({super.key, required this.controller});

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = controller.text;
    final cursorPosition = controller.selection.baseOffset;

    final newText = cursorPosition >= 0
        ? text.substring(0, cursorPosition) +
            emoji.emoji +
            text.substring(cursorPosition)
        : text + emoji.emoji;

    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: (cursorPosition >= 0 ? cursorPosition : text.length) +
          emoji.emoji.length,
    );
  }

  void _onBackspacePressed() {
    final text = controller.text;
    if (text.isEmpty) return;

    final cursorPosition = controller.selection.baseOffset;
    if (cursorPosition <= 0) return;

    final newText =
        text.substring(0, cursorPosition - 1) + text.substring(cursorPosition);
    controller.text = newText;
    controller.selection =
        TextSelection.collapsed(offset: cursorPosition - 1);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: _onEmojiSelected,
        onBackspacePressed: _onBackspacePressed,
        config: Config(
          height: 250,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28,
            verticalSpacing: 0,
            horizontalSpacing: 0,
            gridPadding: EdgeInsets.zero,
            recentsLimit: 28,
            replaceEmojiOnLimitExceed: true,
            noRecents: Text(
              'Nessun emoji recente',
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textTertiary(context),
              ),
            ),
            loadingIndicator: Center(
              child: CircularProgressIndicator(
                color: NovaColors.primary(context),
              ),
            ),
            buttonMode: ButtonMode.MATERIAL,
            backgroundColor: NovaColors.surface(context),
          ),
          categoryViewConfig: CategoryViewConfig(
            initCategory: Category.RECENT,
            backgroundColor: NovaColors.surface(context),
            indicatorColor: NovaColors.primary(context),
            iconColor: NovaColors.textTertiary(context),
            iconColorSelected: NovaColors.primary(context),
            tabIndicatorAnimDuration: kTabScrollDuration,
            categoryIcons: const CategoryIcons(),
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: NovaColors.surface(context),
            buttonColor: NovaColors.primary(context),
            buttonIconColor: NovaColors.onPrimaryLight,
            showBackspaceButton: true,
            showSearchViewButton: true,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: NovaColors.surface(context),
            buttonIconColor: NovaColors.textSecondary(context),
            hintText: 'Cerca emoji...',
          ),
        ),
      ),
    );
  }
}
