// Widget: OffersManagementSection
// Feature: Event Help Requests
// Purpose: Section in EventDetailScreen for event creators to manage received offers
//
// Design: Expandable cards for each help request with inline offer management
// - Shows request description with pending offers count
// - Expandable to show all offers
// - Accept/Decline buttons inline
// - Visual distinction for fulfilled requests

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../domain/entities/event_help_request.dart';
import '../providers/event_help_provider.dart';

/// Section for event creators to manage help requests and offers
class OffersManagementSection extends ConsumerWidget {
  final String eventId;
  final String creatorId;

  const OffersManagementSection({
    super.key,
    required this.eventId,
    required this.creatorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsState = ref.watch(eventHelpRequestsProvider(eventId));

    if (requestsState.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (requestsState.requests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovaColors.helpBackground,
                ),
                child: const Center(
                  child: Icon(
                    Icons.handshake_outlined,
                    size: 18,
                    color: NovaColors.helpAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Le tue richieste di aiuto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Requests list
          ...requestsState.requests.map(
            (request) => _HelpRequestCard(
              request: request,
              eventId: eventId,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card for a single help request with expandable offers
class _HelpRequestCard extends ConsumerStatefulWidget {
  final EventHelpRequest request;
  final String eventId;

  const _HelpRequestCard({
    required this.request,
    required this.eventId,
  });

  @override
  ConsumerState<_HelpRequestCard> createState() => _HelpRequestCardState();
}

class _HelpRequestCardState extends ConsumerState<_HelpRequestCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final offersState = ref.watch(helpOffersProvider(widget.request.id));
    final pendingOffers = offersState.offers.where((o) => o.isPending).toList();
    final acceptedOffers =
        offersState.offers.where((o) => o.isAccepted).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: widget.request.isFulfilled
              ? NovaColors.successLight.withValues(alpha: 0.1)
              : NovaColors.grayLight,
          borderRadius: NovaRadius.circularS,
          border: Border.all(
            color: widget.request.isFulfilled
                ? NovaColors.successLight
                : NovaColors.grayMedium,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header - tappable to expand
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: NovaRadius.circularS,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Request description
                    Expanded(
                      child: Text(
                        widget.request.description,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status indicator
                    if (widget.request.isFulfilled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: NovaColors.successLight,
                          borderRadius: NovaRadius.circularS,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'OK',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (pendingOffers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: NovaColors.helpAccent,
                          borderRadius: NovaRadius.circularS,
                        ),
                        child: Text(
                          '${pendingOffers.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    const SizedBox(width: 8),

                    // Expand/collapse icon
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 24,
                      color: NovaColors.grayDark,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded content - offers list
            if (_isExpanded) ...[
              const Divider(height: 1),
              _buildOffersList(offersState, pendingOffers, acceptedOffers),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList(
    HelpOffersState state,
    List<EventHelpOffer> pendingOffers,
    List<EventHelpOffer> acceptedOffers,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (state.offers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nessuna offerta ancora',
          style: TextStyle(
            fontSize: 14,
            color: NovaColors.grayDark,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accepted offers first
          if (acceptedOffers.isNotEmpty) ...[
            const Text(
              'Accettati',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NovaColors.successLight,
              ),
            ),
            const SizedBox(height: 8),
            ...acceptedOffers
                .map((offer) => _buildOfferTile(offer, isAccepted: true)),
            if (pendingOffers.isNotEmpty) const SizedBox(height: 12),
          ],

          // Pending offers
          if (pendingOffers.isNotEmpty) ...[
            const Text(
              'In attesa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NovaColors.helpAccent,
              ),
            ),
            const SizedBox(height: 8),
            ...pendingOffers
                .map((offer) => _buildOfferTile(offer, isAccepted: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferTile(EventHelpOffer offer, {required bool isAccepted}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: NovaRadius.circularXs,
          border: Border.all(
            color: isAccepted ? NovaColors.successLight : NovaColors.grayMedium,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      NovaColors.brandViolet.withValues(alpha: 0.2),
                  backgroundImage: offer.userAvatarUrl != null
                      ? NetworkImage(offer.userAvatarUrl!)
                      : null,
                  child: offer.userAvatarUrl == null
                      ? Text(
                          (offer.userName ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: NovaColors.brandViolet,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                // Name and class
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.userName ?? 'Utente',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (offer.userClass != null &&
                          offer.userClass!.isNotEmpty)
                        Text(
                          offer.userClass!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: NovaColors.grayDark,
                          ),
                        ),
                    ],
                  ),
                ),
                // Accepted badge
                if (isAccepted)
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: NovaColors.successLight,
                  ),
              ],
            ),

            // Message (if any)
            if (offer.message != null && offer.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NovaColors.grayLight,
                  borderRadius: NovaRadius.circularXs,
                ),
                child: Text(
                  '"${offer.message}"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Action buttons (only for pending)
            if (!isAccepted) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Accept button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleAccept(offer.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NovaColors.successLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: NovaRadius.circularXs,
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Accetta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Decline button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleDecline(offer.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NovaColors.grayDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: NovaRadius.circularXs,
                        ),
                        side: const BorderSide(color: NovaColors.grayMedium),
                      ),
                      child: const Text(
                        'Rifiuta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept(String offerId) async {
    final notifier = ref.read(helpOffersProvider(widget.request.id).notifier);
    final success = await notifier.acceptOffer(offerId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offerta accettata!'),
            backgroundColor: NovaColors.successLight,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nell\'accettazione'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDecline(String offerId) async {
    final notifier = ref.read(helpOffersProvider(widget.request.id).notifier);
    final success = await notifier.declineOffer(offerId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offerta rifiutata'),
            backgroundColor: NovaColors.grayDark,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel rifiuto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
