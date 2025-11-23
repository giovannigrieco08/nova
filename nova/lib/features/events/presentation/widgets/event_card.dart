// Widget: EventCard
// Feature: 003-events-feed (Instagram-style rewrite)
// Purpose: Flat Instagram-style event card with inline caption and native components
//
// Design Specs: VISUAL-REFERENCE-GUIDE.md + CLAUDE-CODE-PROMPT.md
// - Pure white background (no glassmorphism)
// - 1:1 image aspect ratio
// - Username + description INLINE (RichText)
// - Pixel-perfect spacing (6.375px image padding, 1.5px action icon offset)
// - Instagram colors (#0095f6 button, #ed4956 like active)

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io' show Platform;
import '../../domain/entities/event.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../profile/presentation/screens/other_profile_screen.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool showParticipantBadge;

  // TODO(#003): Add these fields to Event model via JOIN with profiles table (requires data layer update)
  final String? organizerName;
  final String? organizerClass;
  final String? creatorId; // Creator's user ID for profile navigation (T050)
  final String? emoji;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isParticipating; // Nuovo: traccia se l'utente partecipa già

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showParticipantBadge = false,
    // Temporary props until data layer updated
    this.organizerName,
    this.organizerClass,
    this.creatorId, // T050: Required for profile navigation
    this.emoji,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isParticipating = false, // Default: non partecipante
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> with SingleTickerProviderStateMixin {
  bool _isCaptionExpanded = false;  // Caption "altro" expansion
  late bool _isLiked;
  late bool _isParticipating; // Traccia stato partecipazione (ottimistico)

  // Animation for double tap like (Instagram-style)
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _isParticipating = widget.isParticipating;

    // Initialize like animation controller
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Scale animation: 0.0 → 1.2 → 0.0 with opacity
    _likeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_likeAnimationController);
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Card separator per specs
      color: Colors.white, // Pure white background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildImage(),
          _buildActions(),
          _buildLikesAndParticipants(), // Nuovo: mostra likes + partecipanti
          _buildCaption(),
          _buildCommentsPreview(), // Sempre visibile (stile BeReal)
          _buildParticipateButton(),
          _buildMetaInfo(),
          _buildTimestamp(),
        ],
      ),
    );
  }

  /// Header: Avatar (32px) + Username (14px bold) + Class (12px) + Menu dots
  Widget _buildHeader() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final organizerClass = widget.organizerClass ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // Avatar with brand gradient (clickable - T050)
          GestureDetector(
            onTap: _navigateToCreatorProfile,
            child: _buildAvatar(organizerName),
          ),
          const SizedBox(width: 10),
          // Username + Class stacked (clickable - T050)
          Expanded(
            child: GestureDetector(
              onTap: _navigateToCreatorProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    organizerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (organizerClass.isNotEmpty)
                    Text(
                      organizerClass,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: NovaColors.instagramUsernameGray,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Menu dots
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _showMenuSheet,
          ),
        ],
      ),
    );
  }

  /// Avatar: 32x32px circle with brand gradient and initials
  Widget _buildAvatar(String name) {
    final initials = _getInitials(name);

    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFF833ab4), // Brand purple
            Color(0xFFfd1d1d), // Brand pink
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

  /// Image: 1:1 aspect ratio, 6.375px padding, 14px radius
  /// Double tap to like (Instagram-style)
  Widget _buildImage() {
    final hasImage = widget.event.imageUrl != null;
    final emoji = widget.emoji;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.375), // EXACT per specs
      child: AspectRatio(
        aspectRatio: 1.0, // 1:1 square
        child: GestureDetector(
          onDoubleTap: _handleDoubleTapLike,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: emoji != null
                    ? _buildEmojiPlaceholder(emoji)
                    : hasImage
                        ? _buildNetworkImage(widget.event.imageUrl!)
                        : _buildDefaultPlaceholder(),
              ),

              // Animated heart overlay (Instagram-style)
              AnimatedBuilder(
                animation: _likeAnimation,
                builder: (context, child) {
                  return _likeAnimation.value > 0.0
                      ? Opacity(
                          opacity: _likeAnimation.value,
                          child: Transform.scale(
                            scale: _likeAnimation.value,
                            child: const Icon(
                              Icons.favorite,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Emoji placeholder (120px font size, #F0F0F0 background)
  Widget _buildEmojiPlaceholder(String emoji) {
    return Container(
      color: NovaColors.dividerLight,
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
        color: NovaColors.dividerLight,
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
      color: NovaColors.dividerLight,
      child: const Center(
        child: Icon(
          Icons.event_rounded,
          size: 64,
          color: NovaColors.textTertiaryLight,
        ),
      ),
    );
  }

  /// Actions: Like (24px) + Comment (24px) with counts
  Widget _buildActions() {
    final likeCount = widget.likeCount;
    // T029: Use event.commentCount from Event model instead of widget parameter
    final commentCount = widget.event.commentCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Like button with count
          GestureDetector(
            onTap: _handleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 24,
                  color: _isLiked ? NovaColors.instagramRed : Colors.black,
                ),
                if (likeCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$likeCount',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Comment button with count (T029: Uses event.commentCount)
          GestureDetector(
            onTap: _handleComment,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 24,
                  color: Colors.black,
                ),
                if (commentCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$commentCount',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  /// Caption: Username (bold) + description (regular) INLINE, max 2 lines collapsed
  Widget _buildCaption() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final description = widget.event.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    color: NovaColors.instagramUsernameGray,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Check if caption exceeds 2 lines using TextPainter
  bool _shouldShowMoreButton() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final description = widget.event.description;
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
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 24); // Account for padding

    return textPainter.didExceedMaxLines;
  }

  /// Button: "Partecipo" full-width, #8B5CF6 (purple navbar), 10px padding
  /// Toggle: partecipa/rimuovi partecipazione
  Widget _buildParticipateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _handleParticipate, // Sempre abilitato (toggle)
          style: ElevatedButton.styleFrom(
            backgroundColor: _isParticipating
                ? NovaColors.dividerLight // Grigio se già partecipante
                : NovaColors.primaryLight, // Viola se non partecipante
            foregroundColor: _isParticipating
                ? NovaColors.instagramUsernameGray // Grigio scuro per testo
                : Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _isParticipating ? 'Già partecipante' : 'Partecipo',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Meta info: Date + time + location (12px icons/text, #737373)
  Widget _buildMetaInfo() {
    final formattedDate = widget.event.formattedDateTime; // Use Event's formatted date/time
    final location = widget.event.location ?? 'Nessuna posizione';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            size: 12,
            color: NovaColors.instagramUsernameGray,
          ),
          const SizedBox(width: 4),
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: NovaColors.instagramUsernameGray,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.location_on,
            size: 12,
            color: NovaColors.instagramUsernameGray,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              location,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: NovaColors.instagramUsernameGray,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Timestamp: "2 ORE FA" UPPERCASE (10px, #737373)
  Widget _buildTimestamp() {
    final timestamp = _formatTimestamp(widget.event.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Text(
        timestamp.toUpperCase(), // UPPERCASE per specs
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: NovaColors.instagramUsernameGray,
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

  /// Navigate to creator's profile (T050)
  void _navigateToCreatorProfile() {
    // Safety check: need creatorId to navigate
    if (widget.creatorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo non disponibile')),
      );
      return;
    }

    // Platform-adaptive navigation
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (_) => OtherProfileScreen(userId: widget.creatorId!),
            )
          : MaterialPageRoute(
              builder: (_) => OtherProfileScreen(userId: widget.creatorId!),
            ),
    );
  }

  void _handleLike() {
    if (!mounted) return; // Safety check
    setState(() {
      _isLiked = !_isLiked;
    });
    // TODO(#003): Call EventsRepository to toggle like optimistically (FR-015)
  }

  /// Handle double tap on image (Instagram-style like)
  void _handleDoubleTapLike() {
    // Safety checks before animation
    if (!mounted) return;

    // Only toggle like if not already liked (Instagram behavior)
    if (!_isLiked) {
      _handleLike();
    }

    // Always play animation regardless of like state
    // Check controller is not disposed
    if (_likeAnimationController.isAnimating || _likeAnimationController.status == AnimationStatus.completed) {
      _likeAnimationController.reset();
    }
    _likeAnimationController.forward(from: 0.0);
  }

  void _handleComment() {
    // TODO(US5): Show comments bottom sheet (requires comments feature implementation)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments sheet coming soon')),
    );
  }

  void _handleParticipate() {
    if (!mounted) return; // Safety check

    // Toggle ottimistico dello stato di partecipazione
    setState(() {
      _isParticipating = !_isParticipating;
    });

    // TODO(#003): Call EventsRepository to toggle participation
    // if (_isParticipating) {
    //   await eventsRepository.participateInEvent(widget.event.id);
    // } else {
    //   await eventsRepository.removeParticipation(widget.event.id);
    // }
  }

  void _showMenuSheet() {
    // TODO(#003): Show platform-adaptive action sheet (CupertinoActionSheet on iOS, ModalBottomSheet on Android)
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Condividi'),
              onTap: () {
                Navigator.pop(context);
                // TODO(US4): Call ShareService.shareEvent() (deep link sharing)
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Segnala'),
              onTap: () {
                Navigator.pop(context);
                // TODO(US8): Show report event dialog (content moderation)
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // EXPANDED SECTIONS (shown when card is expanded)
  // =========================================================================

  /// Likes and participants count (Instagram-style)
  Widget _buildLikesAndParticipants() {
    final likeCount = widget.likeCount;
    // TODO(#003): Get real participant count from EventsRepository.getParticipationCount (FR-024)
    // Mock: mostra sempre un numero per testing
    final participantCount = 12; // Mock data

    // Se entrambi sono 0, non mostrare nulla
    if (likeCount == 0 && participantCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Row(
        children: [
          if (likeCount > 0)
            Text(
              '$likeCount ${likeCount == 1 ? "mi piace" : "mi piace"}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          if (likeCount > 0 && participantCount > 0)
            const Text(
              '  •  ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: NovaColors.instagramUsernameGray,
              ),
            ),
          if (participantCount > 0)
            Text(
              '$participantCount ${participantCount == 1 ? "partecipante" : "partecipanti"}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
        ],
      ),
    );
  }

  /// Comments preview (BeReal-style: always visible with usernames)
  /// Opzione C: Minimal style - less prominent than caption
  Widget _buildCommentsPreview() {
    // TODO(US5): Get real comments from EventsRepository.getEventComments (FR-027)
    final commentCount = widget.commentCount;

    // Mock data per ora
    final mockComments = [
      {'username': 'mario.rossi', 'text': 'Ci sarò!'},
      {'username': 'giulia_98', 'text': 'Che bello 🎉'},
      {'username': 'luca.b', 'text': 'A che ora inizia?'},
    ];

    if (commentCount == 0 && mockComments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), // Ridotto da 4px a 2px
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show first 2 comments (BeReal style)
          ...mockComments.take(2).map((comment) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13, // Ridotto da 14px a 13px
                  fontWeight: FontWeight.w400,
                  color: NovaColors.instagramCommentGray, // Grigio chiaro (era nero)
                  height: 1.3,
                ),
                children: [
                  TextSpan(
                    text: '${comment['username']} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500, // Semi-bold (era w600)
                      color: NovaColors.instagramUsernameGray, // Grigio medio
                    ),
                  ),
                  TextSpan(text: comment['text']),
                ],
              ),
            ),
          )),

          // "Vedi tutti i commenti" link
          if (commentCount > 2)
            GestureDetector(
              onTap: _handleComment,
              child: Padding(
                padding: const EdgeInsets.only(top: 2), // Ridotto da 4px a 2px
                child: Text(
                  'Vedi tutti i $commentCount commenti',
                  style: const TextStyle(
                    fontSize: 13, // Ridotto da 14px a 13px
                    fontWeight: FontWeight.w400,
                    color: NovaColors.instagramUsernameGray,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
