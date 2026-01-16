// Screen: EventDetailScreen
// Feature: 004-event-creation-moderation (Phase 6 - Event Sharing)
// Purpose: Display full event details with Instagram-style layout
//
// Design: Instagram-style consistent with EventCard
// - 1:1 hero image with double-tap like
// - Actions row (like, comment, share)
// - Inline caption style
// - Participate button with count
// - Meta info with icons

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/animations/heart_explosion_animation.dart';
import '../../../../core/animations/animated_like_button.dart';
import '../../../../core/animations/page_transitions.dart';
import '../providers/event_detail_provider.dart';
import '../providers/events_feed_provider.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';
import '../../../comments/presentation/screens/comments_sheet.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';
import '../widgets/offers_management_section.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  /// Event ID to display
  /// - If null, expects Event object passed via route arguments
  /// - If provided, fetches event by ID (deep link navigation)
  final String? eventId;

  const EventDetailScreen({
    super.key,
    this.eventId,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  // State for interactions
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = false;
  bool _isParticipating = false;
  bool _isParticipateLoading = false;
  int _participantCount = 0;
  int _commentCount = 0;
  bool _isCaptionExpanded = false;

  // Event data (loaded once)
  Event? _event;
  bool _stateInitialized = false;

  void _initializeState(Event event) {
    if (!_stateInitialized) {
      _event = event;
      // TODO: Load actual counts from event data when available
      _likeCount = 0;
      _commentCount = 0;
      _participantCount = 0;
      _isLiked = false;
      _isParticipating = false;
      _stateInitialized = true;

      // Load participation state asynchronously
      _loadParticipationState(event.id);
    }
  }

  /// Load the current user's participation state from database
  Future<void> _loadParticipationState(String eventId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      final repository = ref.read(eventsRepositoryProvider);
      final isParticipating = await repository.isUserParticipating(
        eventId: eventId,
        userId: userId,
      );

      if (mounted) {
        setState(() {
          _isParticipating = isParticipating;
        });
      }
    } catch (e) {
      // Silently fail - user can still interact
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);

    // If eventId provided, fetch event by ID (deep link navigation)
    if (widget.eventId != null) {
      final eventAsync = ref.watch(eventDetailProvider(widget.eventId!));

      return Scaffold(
        backgroundColor: NovaColors.backgroundLight,
        appBar: _buildAppBar(context, null),
        body: eventAsync.when(
          data: (event) {
            if (event == null) {
              return _buildErrorState(
                context,
                'Evento non trovato',
                'Questo evento non esiste o è stato eliminato.',
              );
            }

            // Handle pending event (only creator and moderators can see)
            if (event.status == EventStatus.pending &&
                event.creatorId != currentUserId) {
              return _buildErrorState(
                context,
                'Evento in attesa',
                'Questo evento è in attesa di moderazione.',
              );
            }

            // Handle rejected event (only creator can see)
            if (event.status == EventStatus.rejected &&
                event.creatorId != currentUserId) {
              return _buildErrorState(
                context,
                'Evento non disponibile',
                'Questo evento non è disponibile.',
              );
            }

            _initializeState(event);
            return _buildEventContent(context, event, currentUserId);
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                NovaColors.primary(context),
              ),
            ),
          ),
          error: (error, stack) => _buildErrorState(
            context,
            'Errore',
            'Impossibile caricare l\'evento: $error',
          ),
        ),
      );
    }

    // Otherwise, expect Event object from route arguments
    final event = ModalRoute.of(context)!.settings.arguments as Event;
    _initializeState(event);

    return Scaffold(
      backgroundColor: NovaColors.backgroundLight,
      appBar: _buildAppBar(context, event),
      body: _buildEventContent(context, event, currentUserId),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Event? event) {
    return AppBar(
      backgroundColor: NovaColors.backgroundLight,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: NovaColors.textPrimaryLight, size: 24),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Indietro',
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, color: NovaColors.textPrimaryLight),
          onPressed: () => _showMenuSheet(event),
          tooltip: 'Altre opzioni',
        ),
      ],
    );
  }

  Widget _buildEventContent(
    BuildContext context,
    Event event,
    String? currentUserId,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Image (1:1 aspect ratio)
          _buildHeroImage(event),

          // Actions Row
          _buildActionsRow(event),

          // Engagement counts
          _buildEngagementCounts(),

          // Caption (inline style)
          _buildCaption(event),

          // Participate Section
          _buildParticipateSection(event),

          // Meta Info
          _buildMetaInfo(event),

          // Comments Preview
          _buildCommentsPreview(event),

          // Timestamp
          _buildTimestamp(event),

          // Status badge (only for creator, non-approved events)
          if (event.creatorId == currentUserId &&
              event.status != EventStatus.approved)
            _buildStatusBadge(event),

          // Rejection reason
          if (event.status == EventStatus.rejected &&
              event.creatorId == currentUserId &&
              event.rejectionReason != null)
            _buildRejectionReason(event),

          // Help requests management section (only for event creator)
          if (event.creatorId == currentUserId)
            OffersManagementSection(
              eventId: event.id,
              creatorId: event.creatorId,
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // HERO IMAGE
  // ===========================================================================

  Widget _buildHeroImage(Event event) {
    final hasImage = event.imageUrl != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.375),
      child: AspectRatio(
        aspectRatio: 3 / 4, // 3:4 portrait (BeReal-style)
        child: ClipRRect(
          borderRadius: NovaRadius.circularS,
          child: DoubleTapLikeOverlay(
            onDoubleTap: _handleDoubleTapLike,
            child: hasImage
                ? _buildNetworkImage(event.imageUrl!)
                : _buildDefaultPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: NovaColors.placeholder,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => _buildDefaultPlaceholder(),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: NovaColors.placeholder,
      child: Center(
        child: Icon(
          Icons.event_rounded,
          size: 64,
          color: NovaColors.handleBar,
        ),
      ),
    );
  }

  // ===========================================================================
  // ACTIONS ROW
  // ===========================================================================

  Widget _buildActionsRow(Event event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Like button with animation
          AnimatedLikeButton(
            isLiked: _isLiked,
            onTap: _handleLike,
            size: 24,
          ),
          const SizedBox(width: 2),
          // Comment icon
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined, size: 24),
            color: NovaColors.textPrimaryLight,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _openCommentsSheet(event),
          ),
          const Spacer(),
          // Share icon - rounded style for softer look
          IconButton(
            icon: Transform.rotate(
              angle: -0.4, // ~-23 degrees for Instagram-style tilt
              child: const Icon(
                Icons.send_rounded,
                size: 24,
              ),
            ),
            color: NovaColors.textPrimaryLight,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _handleShare(event),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ENGAGEMENT COUNTS
  // ===========================================================================

  Widget _buildEngagementCounts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_likeCount > 0)
            Text(
              '$_likeCount ${_likeCount == 1 ? "mi piace" : "mi piace"}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NovaColors.textPrimaryLight,
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CAPTION
  // ===========================================================================

  Widget _buildCaption(Event event) {
    final organizerName = event.creatorName ?? 'Organizzatore';
    final description = event.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title as header
          Text(
            event.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: NovaColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          // Description with organizer inline (tappable name)
          RichText(
            maxLines: _isCaptionExpanded ? null : 3,
            overflow: _isCaptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: NovaColors.textPrimaryLight,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: '$organizerName ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _navigateToOrganizerProfile(event),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
          if (_shouldShowMoreButton(organizerName, description))
            GestureDetector(
              onTap: () => setState(() => _isCaptionExpanded = !_isCaptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _isCaptionExpanded ? 'meno' : 'altro',
                  style: TextStyle(
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

  bool _shouldShowMoreButton(String organizerName, String description) {
    final fullText = '$organizerName $description';
    final textPainter = TextPainter(
      text: TextSpan(
        text: fullText,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
      ),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 16);

    return textPainter.didExceedMaxLines;
  }

  // ===========================================================================
  // PARTICIPATE SECTION
  // ===========================================================================

  Widget _buildParticipateSection(Event event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          // Partecipo button
          Expanded(
            child: ElevatedButton(
              onPressed: _isParticipating ? null : _handleParticipate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isParticipating
                    ? NovaColors.grayMedium
                    : NovaColors.brandViolet,
                foregroundColor: _isParticipating
                    ? NovaColors.textSecondaryLight
                    : NovaColors.onPrimaryLight,
                disabledBackgroundColor: NovaColors.grayMedium,
                disabledForegroundColor: NovaColors.textSecondaryLight,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: NovaRadius.circularXs,
                ),
              ),
              child: Text(
                _isParticipating ? 'Partecipo già' : 'Partecipo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Participants indicator
          GestureDetector(
            onTap: () => _showParticipantsSheet(event),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: NovaColors.grayLight,
                borderRadius: NovaRadius.circularXs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: NovaColors.textPrimaryLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _participantCount.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimaryLight,
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

  // ===========================================================================
  // META INFO
  // ===========================================================================

  Widget _buildMetaInfo(Event event) {
    final formattedDate = event.formattedDateTime;
    final location = event.location ?? 'Nessuna posizione';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NovaColors.surfaceLight,
          borderRadius: NovaRadius.circularS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: NovaColors.grayDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: NovaColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: NovaColors.grayDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: NovaColors.textPrimaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Organizer (tappable)
            GestureDetector(
              onTap: () => _navigateToOrganizerProfile(event),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: NovaColors.grayDark,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Organizzato da ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: NovaColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    event.creatorName ?? 'Organizzatore',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.brandViolet,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: NovaColors.brandViolet,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMMENTS PREVIEW
  // ===========================================================================

  Widget _buildCommentsPreview(Event event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View all comments button
          if (_commentCount > 0)
            GestureDetector(
              onTap: () => _openCommentsSheet(event),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Vedi tutti i $_commentCount commenti',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: NovaColors.grayDark,
                  ),
                ),
              ),
            ),
          // Add comment prompt
          GestureDetector(
            onTap: () => _openCommentsSheet(event),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NovaColors.brandViolet.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: NovaColors.brandViolet,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Aggiungi un commento...',
                  style: TextStyle(
                    fontSize: 14,
                    color: NovaColors.grayDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TIMESTAMP
  // ===========================================================================

  Widget _buildTimestamp(Event event) {
    final timestamp = _formatTimestamp(event.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Text(
        timestamp.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: NovaColors.grayDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Adesso';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? "minuto" : "minuti"} fa';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "ora" : "ore"} fa';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "giorno" : "giorni"} fa';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "settimana" : "settimane"} fa';
    }
  }

  // ===========================================================================
  // STATUS BADGE
  // ===========================================================================

  Widget _buildStatusBadge(Event event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: event.status == EventStatus.pending
              ? NovaColors.brandViolet.withValues(alpha: 0.1)
              : NovaColors.likeActive.withValues(alpha: 0.1),
          borderRadius: NovaRadius.circularXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              event.status == EventStatus.pending
                  ? Icons.hourglass_empty
                  : Icons.cancel,
              size: 16,
              color: event.status == EventStatus.pending
                  ? NovaColors.brandViolet
                  : NovaColors.likeActive,
            ),
            const SizedBox(width: 8),
            Text(
              event.status == EventStatus.pending
                  ? 'In attesa di moderazione'
                  : 'Rifiutato',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: event.status == EventStatus.pending
                    ? NovaColors.brandViolet
                    : NovaColors.likeActive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // REJECTION REASON
  // ===========================================================================

  Widget _buildRejectionReason(Event event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NovaColors.likeActive.withValues(alpha: 0.05),
          borderRadius: NovaRadius.circularXs,
          border: Border.all(
            color: NovaColors.likeActive.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Motivo del rifiuto',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: NovaColors.likeActive,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              event.rejectionReason!,
              style: TextStyle(
                fontSize: 14,
                color: NovaColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INTERACTION HANDLERS
  // ===========================================================================

  void _handleDoubleTapLike() async {
    if (_isLiked || _isLikeLoading) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final previousCount = _likeCount;

    setState(() {
      _isLiked = true;
      _likeCount = _likeCount + 1;
      _isLikeLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      await repository.likeEvent(eventId: _event!.id, userId: userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = false;
          _likeCount = previousCount;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  void _handleLike() async {
    if (_isLikeLoading) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final wasLiked = _isLiked;
    final previousCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      _isLikeLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      if (_isLiked) {
        await repository.likeEvent(eventId: _event!.id, userId: userId);
      } else {
        await repository.unlikeEvent(eventId: _event!.id, userId: userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'operazione')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  void _handleParticipate() async {
    if (_isParticipating || _isParticipateLoading) return;

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isParticipating = true;
      _participantCount = _participantCount + 1;
      _isParticipateLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      await repository.participateInEvent(eventId: _event!.id, userId: userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParticipating = false;
          _participantCount = _participantCount - 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la partecipazione')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isParticipateLoading = false;
        });
      }
    }
  }

  void _handleShare(Event event) async {
    try {
      await ShareService.shareEvent(event);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la condivisione')),
        );
      }
    }
  }

  void _openCommentsSheet(Event event) {
    showCommentsSheet(
      context: context,
      eventId: event.id,
      eventTitle: event.title,
    );
  }

  void _navigateToOrganizerProfile(Event event) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: OtherProfileScreen(userId: event.creatorId)),
    );
  }

  void _showParticipantsSheet(Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NovaColors.handleBar,
                borderRadius: NovaRadius.circularXxs,
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Partecipanti',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NovaColors.textPrimaryLight,
                ),
              ),
            ),
            // Empty state
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: NovaColors.handleBar,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nessun partecipante ancora',
                      style: TextStyle(
                        fontSize: 16,
                        color: NovaColors.grayDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sii il primo a partecipare!',
                      style: TextStyle(
                        fontSize: 14,
                        color: NovaColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuSheet(Event? event) {
    if (event == null) return;

    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = event.creatorId == currentUserId;

    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            // Share option
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _handleShare(event);
              },
              child: const Text('Condividi'),
            ),
            // Delete option (only for owner)
            if (isOwner)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteEvent(event);
                },
                child: const Text('Elimina evento'),
              ),
            // Report option (only for non-owner)
            if (!isOwner)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
                child: const Text('Segnala'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Share option
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Condividi'),
                onTap: () {
                  Navigator.pop(context);
                  _handleShare(event);
                },
              ),
              // Delete option (only for owner)
              if (isOwner)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: NovaColors.error(context)),
                  title: Text('Elimina evento', style: TextStyle(color: NovaColors.error(context))),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteEvent(event);
                  },
                ),
              // Report option (only for non-owner)
              if (!isOwner)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Segnala'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog();
                  },
                ),
            ],
          ),
        ),
      );
    }
  }

  /// Confirm and delete event
  void _confirmDeleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina evento'),
        content: const Text('Sei sicuro di voler eliminare questo evento? Questa azione non può essere annullata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: NovaColors.error(context)),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
        if (mounted) {
          Navigator.of(context).pop(); // Return to feed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento eliminato')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showReportDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzionalità di segnalazione in arrivo')),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    BuildContext context,
    String title,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              title,
              style: NovaTextStyles.h2.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              message,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.l,
                  vertical: NovaSpacing.m,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.s),
                ),
              ),
              child: Text(
                'Torna indietro',
                style: NovaTextStyles.button.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
