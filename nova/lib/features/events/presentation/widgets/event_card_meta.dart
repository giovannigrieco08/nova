import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';

/// Meta info: Date + time + location (vertical layout).
/// Location is tappable if event has map coordinates.
class EventCardMeta extends StatelessWidget {
  final String formattedDate;
  final String location;
  final bool hasMapLocation;
  final VoidCallback? onLocationTap;

  const EventCardMeta({
    super.key,
    required this.formattedDate,
    required this.location,
    required this.hasMapLocation,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: NovaColors.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: NovaColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: hasMapLocation ? onLocationTap : null,
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: hasMapLocation
                      ? NovaColors.primary(context)
                      : NovaColors.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasMapLocation
                          ? NovaColors.primary(context)
                          : NovaColors.textSecondary(context),
                      decoration: hasMapLocation
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: NovaColors.primary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasMapLocation) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: NovaColors.primary(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
