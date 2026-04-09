// Widget: EventCard
// Feature: 003-events-feed (Instagram-style rewrite)
// Purpose: Flat Instagram-style event card with inline caption and native components
//
// Design Specs: VISUAL-REFERENCE-GUIDE.md + CLAUDE-CODE-PROMPT.md
// - Pure white background (no glassmorphism)
// - 3:4 image aspect ratio (full width, edge-to-edge)
// - Username + description INLINE (RichText)
// - Pixel-perfect spacing (1.5px action icon offset)
// - Instagram colors (#0095f6 button, #ed4956 like active)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/models/auth_state.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/event.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/screens/guest_feed_screen.dart';
import '../../../comments/presentation/screens/comments_sheet.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';
import '../providers/events_feed_provider.dart';
import '../providers/event_likes_notifier.dart';
import 'event_card_models.dart';
import 'event_card_header.dart';
import 'event_card_image.dart';
import 'event_card_actions.dart';
import 'event_card_caption.dart';
import 'event_card_participate.dart';
import 'event_card_meta.dart';
import 'event_card_help_badge.dart';
import 'event_card_timestamp.dart';
import 'event_card_sheets.dart';

// Re-export models so existing imports keep working.
export 'event_card_models.dart' show EventCollaborator, HelpRequestInfo;

class EventCard extends ConsumerStatefulWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool showParticipantBadge;

  final String? organizerName;
  final String? organizerClass;
  final String? organizerAvatarUrl;
  final String? emoji;
  final int likeCount;
  final int commentCount;
  final int participantCount;
  final bool isLiked;
  final bool isParticipating;

  final List<EventCollaborator> collaborators;
  final List<HelpRequestInfo> helpRequests;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showParticipantBadge = false,
    this.organizerName,
    this.organizerClass,
    this.organizerAvatarUrl,
    this.emoji,
    this.likeCount = 0,
    this.commentCount = 0,
    this.participantCount = 0,
    this.isLiked = false,
    this.isParticipating = false,
    this.collaborators = const [],
    this.helpRequests = const [],
  });

  @override
  ConsumerState<EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<EventCard> {
  late bool _isParticipating;
  late int _participantCount;
  bool _isParticipateLoading = false;

  @override
  void initState() {
    super.initState();
    _isParticipating = widget.isParticipating;
    _participantCount = widget.participantCount;
  }

  // ---------------------------------------------------------------------------
  // Resolved organizer info (event entity > widget props > fallback)
  // ---------------------------------------------------------------------------

  String get _organizerName =>
      widget.event.creatorName ?? widget.organizerName ?? 'Organizer';

  String get _organizerClass =>
      widget.event.creatorClass ?? widget.organizerClass ?? '';

  String? get _organizerAvatarUrl =>
      widget.event.creatorAvatarUrl ?? widget.organizerAvatarUrl;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final likesState = ref.watch(eventLikesProvider);
    final likesNotifier = ref.read(eventLikesProvider.notifier);
    final eventId = widget.event.id;

    final providerState = likesState.getForEvent(eventId);
    final likeState = likesState.isInitialized(eventId)
        ? providerState
        : EventLikeState(isLiked: widget.isLiked, likeCount: widget.likeCount);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventCardHeader(
              organizerName: _organizerName,
              organizerClass: _organizerClass,
              organizerAvatarUrl: _organizerAvatarUrl,
              collaborators: widget.collaborators,
              onAvatarTap: widget.collaborators.isNotEmpty
                  ? () => showOrganizersSheet(
                        context: context,
                        mainOrganizerName: _organizerName,
                        mainOrganizerClass: _organizerClass,
                        collaborators: widget.collaborators,
                      )
                  : _navigateToCreatorProfile,
              onNameTap: _navigateToCreatorProfile,
              onMenuTap: () => showEventMenuSheet(
                context: context,
                eventId: eventId,
              ),
            ),
            EventCardImage(
              imageUrl: widget.event.imageUrl,
              emoji: widget.emoji,
              isLiked: likeState.isLiked,
              isProcessing: likeState.isProcessing,
              onDoubleTapLike: () =>
                  _handleDoubleTapLike(likesNotifier, eventId),
            ),
            EventCardActions(
              isLiked: likeState.isLiked,
              isProcessing: likeState.isProcessing,
              onLike: () => _handleLike(likesNotifier, eventId),
              onComment: _handleComment,
            ),
            EventCardCaption(
              organizerName:
                  widget.event.creatorName ?? widget.organizerName ?? 'Organizzatore',
              description: widget.event.description,
            ),
            EventCardParticipateButton(
              isParticipating: _isParticipating,
              participantCount: _participantCount,
              isLoading: _isParticipateLoading,
              onToggle: _handleParticipateToggle,
              onShowParticipants: () => showParticipantsSheet(
                context: context,
                ref: ref,
                eventId: eventId,
                eventTitle: widget.event.title,
                onInvite: () => showInviteSheet(
                  context: context,
                  eventId: eventId,
                  eventTitle: widget.event.title,
                ),
              ),
            ),
            EventCardMeta(
              formattedDate: widget.event.formattedDateTime,
              location: widget.event.location ?? 'Nessuna posizione',
              hasMapLocation: widget.event.hasMapLocation,
              onLocationTap: _openLocationInMaps,
            ),
            if (widget.helpRequests.isNotEmpty)
              EventCardHelpBadge(
                helpRequests: widget.helpRequests,
                onOfferHelp: () => _handleOfferHelp(),
              ),
            EventCardTimestamp(createdAt: widget.event.createdAt),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interaction handlers
  // ---------------------------------------------------------------------------

  bool _isGuestUser() {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    return authState is AuthStateGuest;
  }

  void _showGuestPrompt(String action) {
    showGuestSignInPrompt(context: context, ref: ref, action: action);
  }

  void _handleDoubleTapLike(
      EventLikesNotifier likesNotifier, String eventId) async {
    if (_isGuestUser()) {
      _showGuestPrompt('Accedi per mettere mi piace');
      return;
    }
    HapticFeedback.mediumImpact();
    try {
      await likesNotifier.toggleLike(eventId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'operazione')),
        );
      }
    }
  }

  void _handleLike(EventLikesNotifier likesNotifier, String eventId) async {
    if (_isGuestUser()) {
      _showGuestPrompt('Accedi per mettere mi piace');
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await likesNotifier.toggleLike(eventId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'operazione')),
        );
      }
    }
  }

  void _handleComment() {
    if (_isGuestUser()) {
      _showGuestPrompt('Accedi per commentare');
      return;
    }
    HapticFeedback.selectionClick();
    showCommentsSheet(
      context: context,
      eventId: widget.event.id,
      eventTitle: widget.event.title,
    );
  }

  void _handleParticipateToggle() async {
    if (_isGuestUser()) {
      _showGuestPrompt('Accedi per partecipare');
      return;
    }
    if (_isParticipateLoading) return;
    HapticFeedback.mediumImpact();

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final wasParticipating = _isParticipating;

    setState(() {
      _isParticipating = !_isParticipating;
      _participantCount += _isParticipating ? 1 : -1;
      _isParticipateLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      if (!wasParticipating) {
        await repository.participateInEvent(
            eventId: widget.event.id, userId: userId);
      } else {
        await repository.unparticipateFromEvent(
            eventId: widget.event.id, userId: userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParticipating = wasParticipating;
          _participantCount += wasParticipating ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(wasParticipating
                  ? 'Errore durante l\'annullamento'
                  : 'Errore durante la partecipazione')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isParticipateLoading = false);
      }
    }
  }

  void _handleOfferHelp() {
    if (_isGuestUser()) {
      _showGuestPrompt('Accedi per offrire aiuto');
      return;
    }
    final openRequests =
        widget.helpRequests.where((r) => !r.isFulfilled).toList();
    if (openRequests.isEmpty) return;
    handleOfferHelp(
      context: context,
      eventId: widget.event.id,
      openRequests: openRequests,
    );
  }

  void _navigateToCreatorProfile() {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(
        page: OtherProfileScreen(userId: widget.event.creatorId),
      ),
    );
  }

  Future<void> _openLocationInMaps() async {
    final mapsUrl = widget.event.googleMapsUrl;
    if (mapsUrl == null) return;
    try {
      final uri = Uri.parse(mapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire Maps')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'apertura di Maps')),
        );
      }
    }
  }
}
