import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import 'event_card_models.dart';

/// Help requests badge with "Offri aiuto" button.
/// Only shows unfulfilled requests.
class EventCardHelpBadge extends StatelessWidget {
  final List<HelpRequestInfo> helpRequests;
  final VoidCallback onOfferHelp;

  const EventCardHelpBadge({
    super.key,
    required this.helpRequests,
    required this.onOfferHelp,
  });

  @override
  Widget build(BuildContext context) {
    final openRequests = helpRequests.where((r) => !r.isFulfilled).toList();
    if (openRequests.isEmpty) return const SizedBox.shrink();

    final requestCount = openRequests.length;
    final displayText = requestCount == 1
        ? openRequests.first.description
        : '${openRequests.take(2).map((r) => r.description).join(", ")}${requestCount > 2 ? "..." : ""}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NovaColors.helpBackground,
          borderRadius: NovaRadius.circularXs,
          border: Border.all(color: NovaColors.helpBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: NovaColors.helpAccent,
              ),
              child: const Center(
                child: Icon(Icons.handshake_outlined,
                    size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cerca aiuto',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.helpText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onOfferHelp,
              style: TextButton.styleFrom(
                backgroundColor: NovaColors.helpAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: NovaRadius.circularFull,
                ),
              ),
              child: const Text(
                'Offri aiuto',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
