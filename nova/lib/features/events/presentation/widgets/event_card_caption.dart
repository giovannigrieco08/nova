import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';

/// Caption: Username (bold) + description (regular) inline, max 2 lines collapsed.
class EventCardCaption extends StatefulWidget {
  final String organizerName;
  final String description;

  const EventCardCaption({
    super.key,
    required this.organizerName,
    required this.description,
  });

  @override
  State<EventCardCaption> createState() => _EventCardCaptionState();
}

class _EventCardCaptionState extends State<EventCardCaption> {
  bool _isExpanded = false;

  bool get _shouldShowMoreButton {
    final fullText = '${widget.organizerName} ${widget.description}';
    return fullText.length > 80;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: _isExpanded ? null : 2,
            overflow:
                _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: '${widget.organizerName} ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: widget.description),
              ],
            ),
          ),
          if (_shouldShowMoreButton)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _isExpanded ? 'meno' : 'altro',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: NovaColors.grayDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
