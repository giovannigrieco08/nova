import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/animations/heart_explosion_animation.dart';
import '../../../../core/animations/animated_like_button.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';
import '../widgets/event_card_timestamp.dart';
import '../widgets/offers_management_section.dart';

/// All the pure-presentation sections of the event detail screen.
///
/// State values (isLiked, likeCount, etc.) are passed in; mutations are
/// reported via callbacks so the parent [EventDetailScreen] keeps ownership
/// of the state.
class EventDetailBody extends StatefulWidget {
  final Event event;
  final String? currentUserId;

  // Engagement state (owned by parent)
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final bool isParticipating;
  final int participantCount;
  final bool isParticipateLoading;

  // Callbacks
  final VoidCallback onDoubleTapLike;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onParticipateToggle;
  final VoidCallback onShowParticipants;
  final VoidCallback Function(Event) onNavigateToOrganizer;

  const EventDetailBody({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.isParticipating,
    required this.participantCount,
    required this.isParticipateLoading,
    required this.onDoubleTapLike,
    required this.onLike,
    required this.onComment,
    required this.onParticipateToggle,
    required this.onShowParticipants,
    required this.onNavigateToOrganizer,
  });

  @override
  State<EventDetailBody> createState() => _EventDetailBodyState();
}

class _EventDetailBodyState extends State<EventDetailBody> {
  bool _isCaptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroImage(event),
          _buildActionsRow(),
          _buildEngagementCounts(),
          _buildCaption(event),
          _buildParticipateSection(),
          _buildMetaInfo(event),
          _buildCommentsPreview(event),
          _buildTimestamp(event),
          if (event.creatorId == widget.currentUserId &&
              event.status != EventStatus.approved)
            _buildStatusBadge(event),
          if (event.status == EventStatus.rejected &&
              event.creatorId == widget.currentUserId &&
              event.rejectionReason != null)
            _buildRejectionReason(event),
          if (event.creatorId == widget.currentUserId)
            OffersManagementSection(
              eventId: event.id,
              creatorId: event.creatorId,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero image
  // ---------------------------------------------------------------------------

  Widget _buildHeroImage(Event event) {
    final hasImage = event.imageUrl != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.375),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: NovaRadius.circularS,
          child: DoubleTapLikeOverlay(
            onDoubleTap: widget.onDoubleTapLike,
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
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => _buildDefaultPlaceholder(),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: NovaColors.placeholder,
      child: const Center(
        child: Icon(Icons.event_rounded, size: 64, color: NovaColors.handleBar),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions row
  // ---------------------------------------------------------------------------

  Widget _buildActionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          AnimatedLikeButton(
            isLiked: widget.isLiked,
            onTap: widget.onLike,
            size: 24,
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined, size: 24),
            color: NovaColors.textPrimaryLight,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onComment,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Engagement counts
  // ---------------------------------------------------------------------------

  Widget _buildEngagementCounts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.likeCount > 0)
            Text(
              '${widget.likeCount} ${widget.likeCount == 1 ? "mi piace" : "mi piace"}',
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

  // ---------------------------------------------------------------------------
  // Caption
  // ---------------------------------------------------------------------------

  Widget _buildCaption(Event event) {
    final organizerName = event.creatorName ?? 'Organizzatore';
    final description = event.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: NovaColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
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
                    ..onTap = () => widget.onNavigateToOrganizer(event)(),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
          if (_shouldShowMoreButton(organizerName, description))
            GestureDetector(
              onTap: () =>
                  setState(() => _isCaptionExpanded = !_isCaptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _isCaptionExpanded ? 'meno' : 'altro',
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

  // ---------------------------------------------------------------------------
  // Participate section
  // ---------------------------------------------------------------------------

  Widget _buildParticipateSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: widget.isParticipateLoading
                  ? null
                  : widget.onParticipateToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isParticipating
                    ? NovaColors.grayMedium
                    : NovaColors.brandViolet,
                foregroundColor: widget.isParticipating
                    ? NovaColors.textPrimaryLight
                    : NovaColors.onPrimaryLight,
                disabledBackgroundColor: widget.isParticipating
                    ? NovaColors.grayMedium
                    : NovaColors.brandViolet.withAlpha(180),
                disabledForegroundColor: widget.isParticipating
                    ? NovaColors.textSecondaryLight
                    : NovaColors.onPrimaryLight.withAlpha(180),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: NovaRadius.circularXs,
                ),
              ),
              child: widget.isParticipateLoading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isParticipating
                              ? NovaColors.textSecondaryLight
                              : NovaColors.onPrimaryLight,
                        ),
                      ),
                    )
                  : Text(
                      widget.isParticipating
                          ? 'Non partecipo più'
                          : 'Partecipo',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onShowParticipants,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    widget.participantCount.toString(),
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

  // ---------------------------------------------------------------------------
  // Meta info
  // ---------------------------------------------------------------------------

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
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 18, color: NovaColors.grayDark),
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
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: NovaColors.grayDark),
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
            GestureDetector(
              onTap: () => widget.onNavigateToOrganizer(event)(),
              child: Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 18, color: NovaColors.grayDark),
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
                  Icon(Icons.chevron_right,
                      size: 16, color: NovaColors.brandViolet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Comments preview
  // ---------------------------------------------------------------------------

  Widget _buildCommentsPreview(Event event) {
    if (widget.commentCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: GestureDetector(
        onTap: widget.onComment,
        child: Text(
          'Vedi tutti i ${widget.commentCount} commenti',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: NovaColors.grayDark,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Timestamp
  // ---------------------------------------------------------------------------

  Widget _buildTimestamp(Event event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Text(
        EventCardTimestamp.formatTimestamp(event.createdAt).toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: NovaColors.grayDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status badge
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Rejection reason
  // ---------------------------------------------------------------------------

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
}
