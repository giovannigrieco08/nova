// Widget: ProfileBio
// Feature: 006-user-profile (User Story 1 - T035)
// Purpose: Displays bio max 150 chars with emoji support

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Profile bio display widget
///
/// **Design**:
/// - Max 150 characters (enforced by database)
/// - Supports emoji and unicode
/// - NovaTypography.bodyMedium
/// - Left-aligned text
/// - Optional empty state placeholder
///
/// **Usage**:
/// ```dart
/// // With bio
/// ProfileBio(bio: 'Appassionato di fisica e matematica! 🔬📐')
///
/// // Without bio (shows placeholder)
/// ProfileBio(bio: null, placeholder: 'Nessuna biografia')
/// ```
class ProfileBio extends StatelessWidget {
  final String? bio;
  final String? placeholder;
  final TextAlign textAlign;
  final int? maxLines;

  const ProfileBio({
    this.bio,
    this.placeholder,
    this.textAlign = TextAlign.left,
    this.maxLines,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Show placeholder if bio is null or empty
    if (bio == null || bio!.trim().isEmpty) {
      if (placeholder != null) {
        return Text(
          placeholder!,
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textTertiary(context),
            fontStyle: FontStyle.italic,
          ),
          textAlign: textAlign,
        );
      } else {
        return const SizedBox.shrink();
      }
    }

    // Display bio with emoji support
    return Text(
      bio!,
      style: NovaTypography.bodyMedium.copyWith(
        color: NovaColors.textPrimary(context),
        height: 1.5, // Line height for better readability
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}

/// Bio editor with character counter
///
/// **Design**:
/// - TextField with 150 char limit
/// - Character counter "X/150" below field
/// - NovaTypography.bodyMedium
/// - Platform-adaptive (CupertinoTextField iOS, TextField Android)
///
/// **Usage**:
/// ```dart
/// BioEditor(
///   initialValue: profile.bio,
///   onChanged: (value) => editNotifier.updateBio(value),
/// )
/// ```
class BioEditor extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final int maxLength;

  const BioEditor({
    this.initialValue,
    required this.onChanged,
    this.maxLength = 150,
    super.key,
  });

  @override
  State<BioEditor> createState() => _BioEditorState();
}

class _BioEditorState extends State<BioEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _controller.text.length;
    final isOverLimit = currentLength > widget.maxLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bio text field
        TextField(
          controller: _controller,
          maxLines: 3,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: 'Scrivi qualcosa su di te...',
            hintStyle: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textTertiary(context),
            ),
            border: OutlineInputBorder(
              borderRadius: NovaRadius.circularXs,
              borderSide: BorderSide(
                color: NovaColors.borderPrimary(context),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularXs,
              borderSide: BorderSide(
                color: NovaColors.brandViolet,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: NovaRadius.circularXs,
              borderSide: BorderSide(
                color: NovaColors.error(context),
                width: 1,
              ),
            ),
            counterText: '', // Hide default counter
          ),
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),

        SizedBox(height: NovaSpacing.xsmall),

        // Character counter
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$currentLength/${widget.maxLength}',
            style: NovaTypography.bodySmall.copyWith(
              color: isOverLimit
                  ? NovaColors.error(context)
                  : NovaColors.textSecondary(context),
              fontWeight: isOverLimit ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),

        // Warning if over limit
        if (isOverLimit) ...[
          SizedBox(height: NovaSpacing.xsmall),
          Text(
            'Bio troppo lunga. Riduci a massimo ${widget.maxLength} caratteri.',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.error(context),
            ),
          ),
        ],
      ],
    );
  }
}
