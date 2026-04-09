import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';

/// Participate button with participant count indicator.
class EventCardParticipateButton extends StatelessWidget {
  final bool isParticipating;
  final int participantCount;
  final bool isLoading;
  final VoidCallback onToggle;
  final VoidCallback onShowParticipants;

  const EventCardParticipateButton({
    super.key,
    required this.isParticipating,
    required this.participantCount,
    required this.isLoading,
    required this.onToggle,
    required this.onShowParticipants,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isParticipating ? NovaColors.grayMedium : NovaColors.brandViolet,
                foregroundColor:
                    isParticipating ? NovaColors.textTertiaryLight : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: NovaRadius.circularFull,
                ),
              ),
              child: Text(
                isParticipating ? 'Partecipo già' : 'Partecipo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onShowParticipants,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NovaColors.grayLight,
                borderRadius: NovaRadius.circularFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 18, color: Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    participantCount.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
