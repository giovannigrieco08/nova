/// Adaptive search bar widget
///
/// Platform-adaptive search bar that uses CupertinoSearchTextField on iOS
/// and Material SearchBar on Android.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive search bar
class AdaptiveSearchBar extends StatefulWidget {
  final String? initialQuery;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String placeholder;
  final bool autofocus;

  const AdaptiveSearchBar({
    super.key,
    this.initialQuery,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.placeholder = 'Cerca eventi e persone...',
    this.autofocus = false,
  });

  @override
  State<AdaptiveSearchBar> createState() => _AdaptiveSearchBarState();
}

class _AdaptiveSearchBarState extends State<AdaptiveSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return _buildCupertinoSearchBar();
    }
    return _buildMaterialSearchBar();
  }

  Widget _buildCupertinoSearchBar() {
    return CupertinoSearchTextField(
      controller: _controller,
      placeholder: widget.placeholder,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onSuffixTap: _handleClear,
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.s,
        vertical: NovaSpacing.xs,
      ),
      prefixInsets: const EdgeInsets.only(left: NovaSpacing.s),
      suffixInsets: const EdgeInsets.only(right: NovaSpacing.s),
      style: NovaTypography.bodyMedium.copyWith(
        color: NovaColors.textPrimaryStatic,
      ),
      placeholderStyle: NovaTypography.bodyMedium.copyWith(
        color: NovaColors.textTertiaryStatic,
      ),
    );
  }

  Widget _buildMaterialSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surfaceLight,
        borderRadius: BorderRadius.circular(NovaRadius.large),
        border: Border.all(
          color: NovaColors.borderLight,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.textPrimaryStatic,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textTertiaryStatic,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: NovaColors.textSecondaryStatic,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: NovaColors.textSecondaryStatic,
                  ),
                  onPressed: _handleClear,
                  tooltip: 'Cancella',
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.s,
            vertical: NovaSpacing.m,
          ),
        ),
      ),
    );
  }
}
