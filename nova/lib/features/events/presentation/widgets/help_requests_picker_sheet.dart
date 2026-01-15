// Widget: HelpRequestsPickerSheet
// Feature: Event Help Requests
// Purpose: Bottom sheet to select which help request to offer for
//          when there are multiple open requests
//
// Design: Clean list with radio-style selection

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import 'event_card.dart'; // For HelpRequestInfo

/// Bottom sheet for selecting which help request to offer for
class HelpRequestsPickerSheet extends StatelessWidget {
  final List<HelpRequestInfo> requests;
  final void Function(HelpRequestInfo request) onRequestSelected;

  const HelpRequestsPickerSheet({
    super.key,
    required this.requests,
    required this.onRequestSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NovaColors.handleBar,
                  borderRadius: NovaRadius.circularXxs,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Per cosa vuoi offrire aiuto?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Seleziona una richiesta',
              style: TextStyle(
                fontSize: 14,
                color: NovaColors.grayDark,
              ),
            ),
            const SizedBox(height: 16),

            // Requests list
            ...requests.map((request) => _buildRequestTile(context, request)),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(BuildContext context, HelpRequestInfo request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onRequestSelected(request),
          borderRadius: NovaRadius.circularS,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NovaColors.grayLight,
              borderRadius: NovaRadius.circularS,
              border: Border.all(
                color: NovaColors.grayMedium,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Help icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NovaColors.helpBackground,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.handshake_outlined,
                      size: 20,
                      color: NovaColors.helpAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Request description
                Expanded(
                  child: Text(
                    request.description,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Arrow
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: NovaColors.grayDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
