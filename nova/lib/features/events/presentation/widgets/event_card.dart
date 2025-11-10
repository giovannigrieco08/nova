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
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/event.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool showParticipantBadge;

  // TODO: Add these fields to Event model or fetch from joined data
  final String? organizerName;
  final String? organizerClass;
  final String? emoji;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showParticipantBadge = false,
    // Temporary props until data layer updated
    this.organizerName,
    this.organizerClass,
    this.emoji,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isCaptionExpanded = false;  // Caption "altro" expansion
  bool _isCardExpanded = false;      // Full card expansion (participants/comments)
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCardExpansion,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12), // Card separator per specs
          color: const Color(0xFFFFFFFF), // Pure white background
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildImage(),
              _buildActions(),
              _buildCaption(),
              _buildParticipateButton(),
              _buildMetaInfo(),

              // EXPANDED SECTIONS (conditional)
              if (_isCardExpanded) ...[
                _buildDivider(),
                _buildParticipantsSection(),
                _buildDivider(),
                _buildCommentsPreview(),
              ],

              _buildTimestamp(),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleCardExpansion() {
    setState(() {
      _isCardExpanded = !_isCardExpanded;
    });
  }

  /// Header: Avatar (32px) + Username (14px bold) + Class (12px) + Menu dots
  Widget _buildHeader() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final organizerClass = widget.organizerClass ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Avatar with brand gradient
          _buildAvatar(organizerName),
          const SizedBox(width: 10),
          // Username + Class stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  organizerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
                if (organizerClass.isNotEmpty)
                  Text(
                    organizerClass,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF737373),
                    ),
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
            color: Color(0xFFFFFFFF),
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
  Widget _buildImage() {
    final hasImage = widget.event.imageUrl != null;
    final emoji = widget.emoji;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.375), // EXACT per specs
      child: AspectRatio(
        aspectRatio: 1.0, // 1:1 square
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: emoji != null
              ? _buildEmojiPlaceholder(emoji)
              : hasImage
                  ? _buildNetworkImage(widget.event.imageUrl!)
                  : _buildDefaultPlaceholder(),
        ),
      ),
    );
  }

  /// Emoji placeholder (120px font size, #F0F0F0 background)
  Widget _buildEmojiPlaceholder(String emoji) {
    return Container(
      color: const Color(0xFFF0F0F0),
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
        color: const Color(0xFFF0F0F0),
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
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(
          Icons.event_rounded,
          size: 64,
          color: Color(0xFFD0D0D0),
        ),
      ),
    );
  }

  /// Actions: Like (24px) + Comment (24px) with 1.5px offset
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Like icon with 1.5px offset toward center
          Padding(
            padding: const EdgeInsets.only(left: 1.5),
            child: IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                size: 24,
              ),
              color: _isLiked ? const Color(0xFFed4956) : const Color(0xFF000000),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _handleLike,
            ),
          ),
          const Spacer(),
          // Comment icon with 1.5px offset toward center
          Padding(
            padding: const EdgeInsets.only(right: 1.5),
            child: IconButton(
              icon: const Icon(
                Icons.mode_comment_outlined,
                size: 24,
              ),
              color: const Color(0xFF000000),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _handleComment,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                color: Color(0xFF000000),
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
                    color: Color(0xFF737373),
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

  /// Button: "Partecipo" full-width, #0095f6, 10px padding
  Widget _buildParticipateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _handleParticipate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0095f6), // Instagram blue
            foregroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Partecipo',
            style: TextStyle(
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            size: 12,
            color: Color(0xFF737373),
          ),
          const SizedBox(width: 4),
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.location_on,
            size: 12,
            color: Color(0xFF737373),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              location,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF737373),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Text(
        timestamp.toUpperCase(), // UPPERCASE per specs
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: Color(0xFF737373),
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

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    // TODO: Call repository to toggle like optimistically
  }

  void _handleComment() {
    // TODO: Show comments bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments sheet coming soon')),
    );
  }

  void _handleParticipate() {
    // TODO: Show confirmation dialog with CupertinoAlertDialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Partecipazione'),
        content: Text('Vuoi partecipare a "${widget.event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call repository to add participation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partecipazione confermata!')),
              );
            },
            child: const Text('Partecipo'),
          ),
        ],
      ),
    );
  }

  void _showMenuSheet() {
    // TODO: Show action sheet with CupertinoActionSheet (iOS) / showModalBottomSheet (Android)
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
                // TODO: Implement share
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Segnala'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement report
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

  /// Divider between sections
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        height: 1,
        color: const Color(0xFFEFEFEF),
      ),
    );
  }

  /// Participants section (compact view with avatars)
  Widget _buildParticipantsSection() {
    // TODO: Get participants from event data
    final participantCount = 0; // widget.event.participantCount

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participants ($participantCount)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 8),
          if (participantCount > 0)
            // TODO: Add ParticipantAvatars widget here
            Text(
              'Participant avatars will appear here',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF737373),
              ),
            )
          else
            Text(
              'Nessun partecipante ancora',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF737373),
              ),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              // TODO: Show full participants modal
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Participants modal coming soon')),
              );
            },
            child: const Text(
              'Vedi tutti',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0095f6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Comments preview section (shows first 2 comments)
  Widget _buildCommentsPreview() {
    // TODO: Get comments from event data
    final commentCount = 0; // widget.commentCount

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments ($commentCount)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 8),
          if (commentCount > 0)
            // TODO: Add comment widgets here
            Text(
              'Comment previews will appear here',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF737373),
              ),
            )
          else
            Text(
              'Nessun commento ancora',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF737373),
              ),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _handleComment,
            child: Text(
              commentCount > 2 ? 'Vedi tutti i commenti' : 'Aggiungi un commento',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0095f6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
