import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// A widget that displays a rich link preview for URLs in messages.
///
/// Shows:
/// - Preview image (if available)
/// - Title
/// - Description (truncated)
/// - Site name/domain
class LinkPreviewBubble extends StatefulWidget {
  final String url;
  final bool isOwnMessage;

  const LinkPreviewBubble({
    super.key,
    required this.url,
    required this.isOwnMessage,
  });

  /// Extract the first URL from a text string
  static String? extractUrl(String text) {
    final urlRegex = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  /// Check if a URL is valid for preview
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return AnyLinkPreview.isValidLink(url);
  }

  @override
  State<LinkPreviewBubble> createState() => _LinkPreviewBubbleState();
}

class _LinkPreviewBubbleState extends State<LinkPreviewBubble> {
  Metadata? _metadata;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    try {
      final metadata = await AnyLinkPreview.getMetadata(
        link: widget.url,
        cache: const Duration(hours: 24),
      );

      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
          _hasError = metadata == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if loading or error
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_hasError || _metadata == null) {
      return const SizedBox.shrink();
    }

    final isOwn = widget.isOwnMessage;
    final backgroundColor = isOwn
        ? NovaColors.primary(context).withValues(alpha: 0.15)
        : NovaColors.card(context);
    final borderColor = isOwn
        ? NovaColors.primary(context).withValues(alpha: 0.3)
        : NovaColors.border(context);

    return GestureDetector(
      onTap: _openUrl,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: EdgeInsets.only(top: NovaSpacing.xs),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: NovaRadius.circularM,
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview image
            if (_metadata!.image != null)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(NovaRadius.m),
                  topRight: Radius.circular(NovaRadius.m),
                ),
                child: Image.network(
                  _metadata!.image!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),

            // Content
            Padding(
              padding: EdgeInsets.all(NovaSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  if (_metadata!.title != null && _metadata!.title!.isNotEmpty)
                    Text(
                      _metadata!.title!,
                      style: NovaTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isOwn
                            ? NovaColors.textPrimary(context)
                            : NovaColors.textPrimary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (_metadata!.desc != null &&
                      _metadata!.desc!.isNotEmpty) ...[
                    SizedBox(height: NovaSpacing.xxs),
                    Text(
                      _metadata!.desc!,
                      style: NovaTypography.bodySmall.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Domain
                  SizedBox(height: NovaSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 12,
                        color: NovaColors.textTertiary(context),
                      ),
                      SizedBox(width: NovaSpacing.xxs),
                      Expanded(
                        child: Text(
                          _getDomain(widget.url),
                          style: NovaTypography.bodySmall.copyWith(
                            color: NovaColors.textTertiary(context),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      margin: EdgeInsets.only(top: NovaSpacing.xs),
      padding: EdgeInsets.all(NovaSpacing.s),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(color: NovaColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NovaColors.textTertiary(context),
            ),
          ),
          SizedBox(width: NovaSpacing.s),
          Text(
            'Caricamento anteprima...',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }
}
