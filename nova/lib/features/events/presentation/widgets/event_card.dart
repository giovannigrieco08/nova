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
import '../../../../core/theme/nova_colors.dart';
import '../../domain/entities/event.dart';

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

  /// List of collaborators for collaborative events
  final List<EventCollaborator> collaborators;

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
    this.collaborators = const [],
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isCaptionExpanded = false;  // Caption "altro" expansion
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
            _buildTimestamp(),
          ],
        ),
      ),
    );
  }

  /// Header: Avatar(s) + Username(s) + Class + Menu dots
  /// Supports collaborative events with multiple organizers
  Widget _buildHeader() {
    final organizerName = widget.organizerName ?? 'Organizer';
    final organizerClass = widget.organizerClass ?? '';
    final hasCollaborators = widget.collaborators.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          // Avatar(s) - overlapping if collaborative
          if (hasCollaborators)
            _buildCollaboratorAvatars(organizerName)
          else
            _buildAvatar(organizerName),
          const SizedBox(width: 10),
          // Username(s) + Class stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Names row
                if (hasCollaborators)
                  Text(
                    _buildCollaboratorNames(organizerName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    organizerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
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
                    color: Color(0xFF737373),
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

  /// Build overlapping avatars for collaborative events
  Widget _buildCollaboratorAvatars(String mainOrganizerName) {
    final totalCount = 1 + widget.collaborators.length; // Main + collaborators
    final maxShow = 3; // Max avatars to show
    final showCount = totalCount > maxShow ? maxShow : totalCount;

    return SizedBox(
      width: 32 + (showCount - 1) * 16, // Overlap by 16px
      height: 32,
      child: Stack(
        children: [
          // Main organizer avatar (always first/back)
          Positioned(
            left: 0,
            child: _buildAvatar(mainOrganizerName),
          ),
          // Collaborator avatars (overlapping)
          for (int i = 0; i < widget.collaborators.length && i < maxShow - 1; i++)
            Positioned(
              left: (i + 1) * 16.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _buildAvatar(widget.collaborators[i].name),
              ),
            ),
          // "+N" indicator if more than maxShow
          if (totalCount > maxShow)
            Positioned(
              left: (maxShow - 1) * 16.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0E0E0),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+${totalCount - maxShow + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
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
  String _buildCollaboratorNames(String mainOrganizerName) {
    if (widget.collaborators.isEmpty) return mainOrganizerName;

    final names = [mainOrganizerName, ...widget.collaborators.map((c) => c.name)];
    if (names.length <= 2) {
      return names.join(' e ');
    } else {
      return '${names.first}, ${names[1]} e altri';
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

  /// Actions: Like + Comment (left) | Share (right)
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Like icon
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              size: 24,
            ),
            color: _isLiked ? const Color(0xFFed4956) : const Color(0xFF000000),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _handleLike,
          ),
          const SizedBox(width: 2),
          // Comment icon
          IconButton(
            icon: const Icon(
              Icons.mode_comment_outlined,
              size: 24,
            ),
            color: const Color(0xFF000000),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _handleComment,
          ),
          const Spacer(),
          // Share icon (right side) - Instagram-style paper plane
          IconButton(
            icon: Transform.rotate(
              angle: -0.4, // ~-23 degrees for Instagram-style tilt
              child: const Icon(
                Icons.send_rounded,
                size: 22,
              ),
            ),
            color: const Color(0xFF000000),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _handleShare,
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
    )..layout(maxWidth: MediaQuery.of(context).size.width - 16); // Account for padding

    return textPainter.didExceedMaxLines;
  }

  /// Button: "Partecipo" with participants indicator
  Widget _buildParticipateButton() {
    // TODO: Get actual participant count from event data
    final participantCount = 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          // Partecipo button (expanded)
          Expanded(
            child: ElevatedButton(
              onPressed: _handleParticipate,
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.brandViolet,
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
          const SizedBox(width: 8),
          // Participants indicator (tappable) - on the right
          GestureDetector(
            onTap: _showParticipantsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 18,
                    color: Color(0xFF000000),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    participantCount.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
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
  Widget _buildMetaInfo() {
    final formattedDate = widget.event.formattedDateTime;
    final location = widget.event.location ?? 'Nessuna posizione';

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
          // Luogo
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: NovaColors.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: NovaColors.textSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  void _handleShare() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share coming soon')),
    );
  }

  void _handleInvite() {
    // TODO: Open invite sheet to select users to invite
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invita coming soon')),
    );
  }

  void _showParticipantsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                color: const Color(0xFFD0D0D0),
                borderRadius: BorderRadius.circular(2),
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
                          color: Color(0xFF8E8E93),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFF8E8E93),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 36,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF000000),
                      ),
                      onChanged: (query) {
                        // TODO: Filter participants
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
                      color: Color(0xFF000000),
                    ),
                  ),
                ],
              ),
            ),
            // Participants list or empty state
            Expanded(
              child: _buildParticipantsList(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  /// Build participants list or empty state
  Widget _buildParticipantsList(ScrollController scrollController) {
    // TODO: Get actual participants from event data
    final participants = <Map<String, String>>[]; // Empty for now

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: const Color(0xFFD0D0D0),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nessun partecipante ancora',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF737373),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sii il primo a partecipare!',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFA0A0A0),
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
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: NovaColors.brandViolet.withOpacity(0.2),
            child: Text(
              participant['name']?[0].toUpperCase() ?? '?',
              style: TextStyle(
                color: NovaColors.brandViolet,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            participant['name'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF000000),
            ),
          ),
          subtitle: Text(
            participant['class'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF737373),
            ),
          ),
          onTap: () {
            // TODO: Navigate to profile
            Navigator.pop(context);
          },
        );
      },
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
}
