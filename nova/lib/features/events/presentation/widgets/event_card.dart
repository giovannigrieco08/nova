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
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/animations/heart_explosion_animation.dart';
import '../../../../core/animations/animated_like_button.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/event.dart';
import '../providers/events_feed_provider.dart';
import '../../../comments/presentation/screens/comments_sheet.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';
import '../../../../core/animations/page_transitions.dart';
import 'offer_help_sheet.dart';
import 'help_requests_picker_sheet.dart';
import 'invite_users_sheet.dart';

/// Collaborator info for collaborative events
class EventCollaborator {
  final String name;
  final String className;
  final String? avatarUrl;

  const EventCollaborator({
    required this.name,
    required this.className,
    this.avatarUrl,
  });
}

/// Help request info for display in EventCard
/// Contains minimal data needed for UI display and sheet opening
class HelpRequestInfo {
  final String id;
  final String description;
  final bool isFulfilled;

  const HelpRequestInfo({
    required this.id,
    required this.description,
    this.isFulfilled = false,
  });
}

class EventCard extends ConsumerStatefulWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool showParticipantBadge;

  // TODO: Add these fields to Event model or fetch from joined data
  final String? organizerName;
  final String? organizerClass;
  final String? organizerAvatarUrl;
  final String? emoji;
  final int likeCount;
  final int commentCount;
  final int participantCount;
  final bool isLiked;
  final bool isParticipating;

  /// List of collaborators for collaborative events
  final List<EventCollaborator> collaborators;

  /// Help requests for this event (fetched from event_help_requests table)
  /// Uses HelpRequestInfo for minimal data needed to display and open sheets
  final List<HelpRequestInfo> helpRequests;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showParticipantBadge = false,
    // Temporary props until data layer updated
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
  bool _isCaptionExpanded = false;  // Caption "altro" expansion
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeLoading = false;
  late bool _isParticipating;
  late int _participantCount;
  bool _isParticipateLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
    _isParticipating = widget.isParticipating;
    _participantCount = widget.participantCount;
    // Participant data now comes from widget props (fetched by feed provider)
    // Removed per-card network calls that caused 20+ concurrent requests
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), // Card separator per specs
        color: Colors.white, // Pure white background
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildImage(),
            _buildActions(),
            _buildCaption(),
            _buildParticipateButton(),
            _buildMetaInfo(),
            if (widget.helpRequests.isNotEmpty) _buildHelpRequestsBadge(),
            _buildTimestamp(),
          ],
        ),
      ),
    );
  }

  /// Header: Avatar(s) + Username(s) + Class + Menu dots
  /// Supports collaborative events with multiple organizers
  Widget _buildHeader() {
    // Use creator info from event entity (joined from profiles table)
    final organizerName = widget.event.creatorName ?? widget.organizerName ?? 'Organizer';
    final organizerClass = widget.event.creatorClass ?? widget.organizerClass ?? '';
    final organizerAvatarUrl = widget.event.creatorAvatarUrl ?? widget.organizerAvatarUrl;
    final hasCollaborators = widget.collaborators.isNotEmpty;
    final namesInfo = _buildCollaboratorNamesWithCount(organizerName);
    final hasTappableOthers = namesInfo.othersCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          // Avatar(s) - overlapping if collaborative, tappable to show all or navigate to profile
          GestureDetector(
            onTap: hasCollaborators
                ? () => _showOrganizersSheet(organizerName, organizerClass)
                : () => _navigateToCreatorProfile(),
            child: hasCollaborators
                ? _buildCollaboratorAvatars(organizerName, avatarUrl: organizerAvatarUrl)
                : _buildAvatar(organizerName, avatarUrl: organizerAvatarUrl),
          ),
          const SizedBox(width: 10),
          // Username(s) + Class stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Names row - tappable to show organizers sheet or navigate to profile
                GestureDetector(
                  onTap: hasTappableOthers
                      ? () => _showOrganizersSheet(organizerName, organizerClass)
                      : () => _navigateToCreatorProfile(),
                  child: Text(
                    namesInfo.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      decoration: hasTappableOthers ? TextDecoration.none : TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Class info
                Text(
                  hasCollaborators
                      ? _buildCollaboratorClasses(organizerClass)
                      : organizerClass.isNotEmpty ? organizerClass : 'Studente',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: NovaColors.grayDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Menu dots
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _showMenuSheet,
            tooltip: 'Altre opzioni',
          ),
        ],
      ),
    );
  }

  /// Avatar: 32x32px circle with image or brand gradient with initials
  Widget _buildAvatar(String name, {String? avatarUrl}) {
    final initials = _getInitials(name);

    // If avatar URL is available, show the image
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildInitialsAvatar(initials),
          errorWidget: (context, url, error) => _buildInitialsAvatar(initials),
        ),
      );
    }

    // Fallback to initials
    return _buildInitialsAvatar(initials);
  }

  /// Build initials avatar with gradient background
  Widget _buildInitialsAvatar(String initials) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            NovaColors.gradientStart, // Brand purple
            NovaColors.gradientEnd, // Brand pink
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Get initials from name (e.g. "Marco Rossi" -> "MR")
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Build overlapping avatars for collaborative events
  Widget _buildCollaboratorAvatars(String mainOrganizerName, {String? avatarUrl}) {
    final totalCount = 1 + widget.collaborators.length; // Main + collaborators
    final maxShow = 3; // Max avatars to show
    final showCount = totalCount > maxShow ? maxShow : totalCount;

    // Avatar size + border (2px each side = 4px total)
    const avatarSize = 32.0;
    const borderWidth = 2.0;
    const avatarWithBorder = avatarSize + (borderWidth * 2);
    const overlapOffset = 18.0; // How much each avatar overlaps

    return SizedBox(
      width: avatarSize + (showCount - 1) * overlapOffset + (borderWidth * 2),
      height: avatarWithBorder,
      child: Stack(
        clipBehavior: Clip.none, // Prevent clipping
        children: [
          // Main organizer avatar (always first/back)
          Positioned(
            left: 0,
            top: borderWidth, // Center vertically accounting for border
            child: _buildAvatar(mainOrganizerName, avatarUrl: avatarUrl),
          ),
          // Collaborator avatars (overlapping)
          for (int i = 0; i < widget.collaborators.length && i < maxShow - 1; i++)
            Positioned(
              left: (i + 1) * overlapOffset,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: borderWidth),
                ),
                child: _buildAvatar(widget.collaborators[i].name, avatarUrl: widget.collaborators[i].avatarUrl),
              ),
            ),
          // "+N" indicator if more than maxShow
          if (totalCount > maxShow)
            Positioned(
              left: (maxShow - 1) * overlapOffset,
              top: 0,
              child: Container(
                width: avatarWithBorder,
                height: avatarWithBorder,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovaColors.grayMedium,
                  border: Border.all(color: Colors.white, width: borderWidth),
                ),
                child: Center(
                  child: Text(
                    '+${totalCount - maxShow + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build comma-separated names for collaborative events
  /// Returns a record with (displayText, othersCount) for tap handling
  ({String text, int othersCount}) _buildCollaboratorNamesWithCount(String mainOrganizerName) {
    if (widget.collaborators.isEmpty) {
      return (text: mainOrganizerName, othersCount: 0);
    }

    final names = [mainOrganizerName, ...widget.collaborators.map((c) => c.name)];
    if (names.length == 2) {
      return (text: names.join(' e '), othersCount: 0);
    } else {
      final othersCount = names.length - 2;
      final othersText = othersCount == 1 ? 'e 1 altro' : 'e altri $othersCount';
      return (text: '${names.first}, ${names[1]} $othersText', othersCount: othersCount);
    }
  }

  /// Build class info for collaborative events
  String _buildCollaboratorClasses(String mainOrganizerClass) {
    if (widget.collaborators.isEmpty) {
      return mainOrganizerClass.isNotEmpty ? mainOrganizerClass : 'Studente';
    }

    final classes = <String>{};
    if (mainOrganizerClass.isNotEmpty) classes.add(mainOrganizerClass);
    for (final c in widget.collaborators) {
      if (c.className.isNotEmpty) classes.add(c.className);
    }

    if (classes.isEmpty) return 'Studenti';
    if (classes.length == 1) return classes.first;
    return classes.take(2).join(' · ');
  }

  /// Image: 3:4 aspect ratio, full width, 14px radius
  /// Supports double-tap to like with Instagram-style heart animation
  Widget _buildImage() {
    final hasImage = widget.event.imageUrl != null;
    final emoji = widget.emoji;

    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 3 / 4, // 3:4 portrait (BeReal-style)
        child: ClipRRect(
          borderRadius: NovaRadius.circularS,
          child: DoubleTapLikeOverlay(
            onDoubleTap: _handleDoubleTapLike,
            child: emoji != null
                ? _buildEmojiPlaceholder(emoji)
                : hasImage
                    ? _buildNetworkImage(widget.event.imageUrl!)
                    : _buildDefaultPlaceholder(),
          ),
        ),
      ),
    );
  }

  /// Handle double-tap like on image (Instagram-style)
  void _handleDoubleTapLike() async {
    // Only like if not already liked (Instagram behavior)
    if (_isLiked || _isLikeLoading) return;

    // Haptic feedback for double-tap like
    HapticFeedback.mediumImpact();

    // Get current user ID
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final previousCount = _likeCount;

    // Optimistic update
    setState(() {
      _isLiked = true;
      _likeCount = _likeCount + 1;
      _isLikeLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      await repository.likeEvent(eventId: widget.event.id, userId: userId);
    } catch (e) {
      // Revert on error
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
    // Haptic feedback is handled by HeartExplosionAnimation
  }

  /// Emoji placeholder (120px font size, #F0F0F0 background)
  Widget _buildEmojiPlaceholder(String emoji) {
    return Container(
      color: NovaColors.placeholder,
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 120),
        ),
      ),
    );
  }

  /// Network image with caching
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

  /// Default placeholder (#F0F0F0)
  Widget _buildDefaultPlaceholder() {
    return Container(
      color: NovaColors.placeholder,
      child: const Center(
        child: Icon(
          Icons.event_rounded,
          size: 64,
          color: NovaColors.handleBar,
        ),
      ),
    );
  }

  /// Actions: Like + Comment (left) | Share (right)
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Like icon with bounce animation
          AnimatedLikeButton(
            isLiked: _isLiked,
            onTap: _handleLike,
            size: 24,
          ),
          const SizedBox(width: 2),
          // Comment icon
          IconButton(
            icon: const Icon(
              Icons.mode_comment_outlined,
              size: 24,
            ),
            color: Colors.black,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _handleComment,
            tooltip: 'Commenti',
          ),
        ],
      ),
    );
  }

  /// Caption: Username (bold) + description (regular) INLINE, max 2 lines collapsed
  Widget _buildCaption() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final description = widget.event.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: _isCaptionExpanded ? null : 2,
            overflow: _isCaptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: '$organizerName ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
          if (_shouldShowMoreButton())
            GestureDetector(
              onTap: () => setState(() => _isCaptionExpanded = !_isCaptionExpanded),
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

  /// Check if caption exceeds 2 lines using simple character heuristic
  /// Avoids expensive TextPainter.layout() call in build()
  bool _shouldShowMoreButton() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final description = widget.event.description;
    final fullText = '$organizerName $description';

    // ~45 chars per line at font size 14, 2 lines = ~90 chars
    // Use 80 as threshold to account for variable width characters
    return fullText.length > 80;
  }

  /// Button: "Partecipo" with participants indicator (toggleable)
  Widget _buildParticipateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          // Partecipo button (expanded) - toggles participation status
          Expanded(
            child: ElevatedButton(
              onPressed: _isParticipateLoading ? null : _handleParticipateToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isParticipating
                    ? NovaColors.grayMedium
                    : NovaColors.brandViolet,
                foregroundColor: _isParticipating
                    ? NovaColors.textTertiaryLight
                    : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: NovaRadius.circularFull,
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
          // Participants indicator (tappable) - on the right
          GestureDetector(
            onTap: _showParticipantsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: NovaColors.grayLight,
                borderRadius: NovaRadius.circularFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 18,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _participantCount.toString(),
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

  /// Meta info: Date + time + location (vertical layout for prominence)
  /// Location is tappable if event has map coordinates
  Widget _buildMetaInfo() {
    final formattedDate = widget.event.formattedDateTime;
    final location = widget.event.location ?? 'Nessuna posizione';
    final hasMapLocation = widget.event.hasMapLocation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Data
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
          // Luogo - tappable if has coordinates
          GestureDetector(
            onTap: hasMapLocation ? _openLocationInMaps : null,
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

  /// Help requests badge with "Offri aiuto" button
  /// Only shows unfulfilled requests and handles selection logic
  Widget _buildHelpRequestsBadge() {
    // Filter only unfulfilled requests
    final openRequests = widget.helpRequests.where((r) => !r.isFulfilled).toList();
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
          color: NovaColors.helpBackground, // Light orange background
          borderRadius: NovaRadius.circularXs,
          border: Border.all(
            color: NovaColors.helpBorder, // Orange border
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Help icon
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: NovaColors.helpAccent, // Orange
              ),
              child: const Center(
                child: Icon(
                  Icons.handshake_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Request text
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
            // Offer help button
            TextButton(
              onPressed: () => _handleOfferHelp(openRequests),
              style: TextButton.styleFrom(
                backgroundColor: NovaColors.helpAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: NovaRadius.circularFull,
                ),
              ),
              child: const Text(
                'Offri aiuto',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle "Offri aiuto" button tap
  /// If 1 request → open OfferHelpSheet directly
  /// If multiple → open HelpRequestsPickerSheet to choose
  void _handleOfferHelp(List<HelpRequestInfo> openRequests) {
    if (openRequests.length == 1) {
      // Single request - open offer sheet directly
      _showOfferHelpSheet(openRequests.first);
    } else {
      // Multiple requests - show picker first
      _showHelpRequestsPickerSheet(openRequests);
    }
  }

  /// Show the offer help sheet for a specific request
  void _showOfferHelpSheet(HelpRequestInfo request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
      ),
      builder: (context) => OfferHelpSheet(
        requestId: request.id,
        requestDescription: request.description,
        eventId: widget.event.id,
      ),
    );
  }

  /// Show picker sheet when there are multiple help requests
  void _showHelpRequestsPickerSheet(List<HelpRequestInfo> requests) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
      ),
      builder: (context) => HelpRequestsPickerSheet(
        requests: requests,
        onRequestSelected: (request) {
          Navigator.pop(context);
          _showOfferHelpSheet(request);
        },
      ),
    );
  }

  /// Open location in Google Maps (or Apple Maps on iOS)
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

  /// Timestamp: "2 ORE FA" UPPERCASE (10px, #737373)
  Widget _buildTimestamp() {
    final timestamp = _formatTimestamp(widget.event.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Text(
        timestamp.toUpperCase(), // UPPERCASE per specs
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: NovaColors.grayDark,
        ),
      ),
    );
  }

  /// Format timestamp relative to now (e.g. "2 ore fa")
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

  // =========================================================================
  // INTERACTION HANDLERS
  // =========================================================================

  void _handleLike() async {
    // Prevent multiple rapid taps
    if (_isLikeLoading) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Get current user ID
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final wasLiked = _isLiked;
    final previousCount = _likeCount;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      _isLikeLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      if (_isLiked) {
        await repository.likeEvent(eventId: widget.event.id, userId: userId);
      } else {
        await repository.unlikeEvent(eventId: widget.event.id, userId: userId);
      }
    } catch (e) {
      // Revert on error
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

  void _handleComment() {
    // Haptic feedback
    HapticFeedback.selectionClick();

    // Show Instagram-style bottom sheet
    showCommentsSheet(
      context: context,
      eventId: widget.event.id,
      eventTitle: widget.event.title,
    );
  }

  void _handleInvite() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
      ),
      builder: (context) => InviteUsersSheet(
        eventId: widget.event.id,
        eventTitle: widget.event.title,
      ),
    );
  }

  void _showParticipantsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
      ),
      builder: (sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
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
                // Search bar + Invite button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Search field
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cerca',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: NovaColors.grayDark,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: NovaColors.grayDark,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 36,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: NovaRadius.circularXs,
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: NovaColors.grayLight,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          onChanged: (query) {
                            setSheetState(() {
                              searchQuery = query.toLowerCase();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Invite button
                      GestureDetector(
                        onTap: _handleInvite,
                        child: const Icon(
                          Icons.person_add_outlined,
                          size: 24,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                // Participants list or empty state
                Expanded(
                  child: _buildParticipantsList(scrollController, searchQuery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build participants list or empty state
  Widget _buildParticipantsList(ScrollController scrollController, [String searchQuery = '']) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(eventsRepositoryProvider).getParticipants(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: NovaColors.handleBar,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Errore nel caricamento',
                  style: TextStyle(
                    fontSize: 16,
                    color: NovaColors.grayDark,
                  ),
                ),
              ],
            ),
          );
        }

        var participants = snapshot.data ?? [];

        // Filter participants by search query
        if (searchQuery.isNotEmpty) {
          participants = participants.where((p) {
            final name = (p['full_name'] as String? ?? '').toLowerCase();
            final className = (p['class'] as String? ?? '').toLowerCase();
            return name.contains(searchQuery) || className.contains(searchQuery);
          }).toList();
        }

        if (participants.isEmpty) {
          // Different message for search results vs no participants
          final isSearching = searchQuery.isNotEmpty;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSearching ? Icons.search_off : Icons.people_outline,
                  size: 64,
                  color: NovaColors.handleBar,
                ),
                const SizedBox(height: 16),
                Text(
                  isSearching ? 'Nessun risultato' : 'Nessun partecipante ancora',
                  style: const TextStyle(
                    fontSize: 16,
                    color: NovaColors.grayDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSearching ? 'Prova con un altro nome' : 'Sii il primo a partecipare!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: NovaColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participant = participants[index];
            final name = participant['full_name'] as String? ?? '';
            final className = participant['class'] as String? ?? '';
            final avatarUrl = participant['avatar_url'] as String?;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: NovaColors.brandViolet.withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: NovaColors.brandViolet,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              subtitle: className.isNotEmpty
                  ? Text(
                      className,
                      style: const TextStyle(
                        fontSize: 14,
                        color: NovaColors.grayDark,
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _handleParticipateToggle() async {
    // Prevent multiple taps while loading
    if (_isParticipateLoading) return;

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Get current user ID
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final wasParticipating = _isParticipating;

    // Optimistic update
    setState(() {
      _isParticipating = !_isParticipating;
      _participantCount += _isParticipating ? 1 : -1;
      _isParticipateLoading = true;
    });

    try {
      final repository = ref.read(eventsRepositoryProvider);
      if (!wasParticipating) {
        // Was not participating, now participate
        await repository.participateInEvent(eventId: widget.event.id, userId: userId);
      } else {
        // Was participating, now unparticipate
        await repository.unparticipateFromEvent(eventId: widget.event.id, userId: userId);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isParticipating = wasParticipating;
          _participantCount += wasParticipating ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wasParticipating
            ? 'Errore durante l\'annullamento'
            : 'Errore durante la partecipazione')),
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

  /// Navigate to the event creator's profile
  void _navigateToCreatorProfile() {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(
        page: OtherProfileScreen(userId: widget.event.creatorId),
      ),
    );
  }

  /// Show bottom sheet with all organizers (main + collaborators)
  void _showOrganizersSheet(String mainOrganizerName, String mainOrganizerClass) {
    final allOrganizers = [
      EventCollaborator(
        name: mainOrganizerName,
        className: mainOrganizerClass,
      ),
      ...widget.collaborators,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Organizzatori',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: NovaColors.placeholder,
                      borderRadius: NovaRadius.circularS,
                    ),
                    child: Text(
                      '${allOrganizers.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NovaColors.grayDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Organizers list
            ...allOrganizers.asMap().entries.map((entry) {
              final index = entry.key;
              final organizer = entry.value;
              final isMain = index == 0;

              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        NovaColors.gradientStart,
                        NovaColors.gradientEnd,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(organizer.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        organizer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMain) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: NovaColors.brandViolet.withValues(alpha: 0.1),
                          borderRadius: NovaRadius.circularXxs,
                        ),
                        child: Text(
                          'Creatore',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.brandViolet,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  organizer.className.isNotEmpty ? organizer.className : 'Studente',
                  style: const TextStyle(
                    fontSize: 14,
                    color: NovaColors.grayDark,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to profile
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMenuSheet() {
    // Platform-adaptive action sheet
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
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
              ListTile(
                leading: const Icon(Icons.flag),
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

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ReportEventDialog(
        eventId: widget.event.id,
        eventTitle: widget.event.title,
        onReport: (reason, description) async {
          try {
            final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
            if (userId == null) {
              throw Exception('Utente non autenticato');
            }

            final repository = ref.read(eventsRepositoryProvider);
            await repository.reportEvent(
              eventId: widget.event.id,
              userId: userId,
              reason: reason,
              description: description,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Segnalazione inviata. Grazie per il feedback!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    e.toString().contains('duplicate')
                        ? 'Hai già segnalato questo evento'
                        : 'Errore nell\'invio della segnalazione',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

/// Report event dialog with reason selection
class _ReportEventDialog extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final Future<void> Function(String reason, String? description) onReport;

  const _ReportEventDialog({
    required this.eventId,
    required this.eventTitle,
    required this.onReport,
  });

  @override
  State<_ReportEventDialog> createState() => _ReportEventDialogState();
}

class _ReportEventDialogState extends State<_ReportEventDialog> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  static const _reportReasons = [
    ('inappropriate', 'Contenuto inappropriato', 'Contenuti offensivi, volgari o non adatti'),
    ('spam', 'Spam', 'Contenuti pubblicitari o ripetitivi'),
    ('harassment', 'Molestie', 'Bullismo, minacce o contenuti intimidatori'),
    ('misleading', 'Informazioni false', 'Informazioni fuorvianti o non veritiere'),
    ('other', 'Altro', 'Altra motivazione'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segnala evento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleziona il motivo della segnalazione:',
              style: TextStyle(
                color: NovaColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ..._reportReasons.map((reason) => RadioListTile<String>(
              title: Text(reason.$2),
              subtitle: Text(
                reason.$3,
                style: TextStyle(
                  fontSize: 12,
                  color: NovaColors.textTertiary(context),
                ),
              ),
              value: reason.$1,
              groupValue: _selectedReason,
              onChanged: (value) => setState(() => _selectedReason = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descrizione (opzionale)',
                hintText: 'Fornisci dettagli aggiuntivi...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.s),
                ),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null || _isSubmitting
              ? null
              : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Invia'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onReport(
        _selectedReason!,
        _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
