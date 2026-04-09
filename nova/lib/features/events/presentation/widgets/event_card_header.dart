import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/nova_colors.dart';
import 'event_card_models.dart';

/// Header: Avatar(s) + Username(s) + Class + Menu dots.
/// Supports collaborative events with multiple organizers.
class EventCardHeader extends StatelessWidget {
  final String organizerName;
  final String organizerClass;
  final String? organizerAvatarUrl;
  final List<EventCollaborator> collaborators;
  final VoidCallback onAvatarTap;
  final VoidCallback onNameTap;
  final VoidCallback onMenuTap;

  const EventCardHeader({
    super.key,
    required this.organizerName,
    required this.organizerClass,
    required this.organizerAvatarUrl,
    required this.collaborators,
    required this.onAvatarTap,
    required this.onNameTap,
    required this.onMenuTap,
  });

  bool get _hasCollaborators => collaborators.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final namesInfo = _buildCollaboratorNamesWithCount();
    final hasTappableOthers = namesInfo.othersCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: _hasCollaborators
                ? _buildCollaboratorAvatars()
                : _buildAvatar(organizerName, avatarUrl: organizerAvatarUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: hasTappableOthers ? onAvatarTap : onNameTap,
                  child: Text(
                    namesInfo.text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _hasCollaborators
                      ? _buildCollaboratorClasses()
                      : organizerClass.isNotEmpty
                          ? organizerClass
                          : 'Studente',
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
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onMenuTap,
            tooltip: 'Altre opzioni',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar helpers
  // ---------------------------------------------------------------------------

  Widget _buildAvatar(String name, {String? avatarUrl}) {
    final initials = _getInitials(name);

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

    return _buildInitialsAvatar(initials);
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [NovaColors.gradientStart, NovaColors.gradientEnd],
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

  Widget _buildCollaboratorAvatars() {
    final totalCount = 1 + collaborators.length;
    const maxShow = 3;
    final showCount = totalCount > maxShow ? maxShow : totalCount;

    const avatarSize = 32.0;
    const borderWidth = 2.0;
    const avatarWithBorder = avatarSize + (borderWidth * 2);
    const overlapOffset = 18.0;

    return SizedBox(
      width: avatarSize + (showCount - 1) * overlapOffset + (borderWidth * 2),
      height: avatarWithBorder,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: borderWidth,
            child: _buildAvatar(organizerName, avatarUrl: organizerAvatarUrl),
          ),
          for (int i = 0;
              i < collaborators.length && i < maxShow - 1;
              i++)
            Positioned(
              left: (i + 1) * overlapOffset,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: borderWidth),
                ),
                child: _buildAvatar(collaborators[i].name,
                    avatarUrl: collaborators[i].avatarUrl),
              ),
            ),
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

  // ---------------------------------------------------------------------------
  // Name / class helpers
  // ---------------------------------------------------------------------------

  static String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  ({String text, int othersCount}) _buildCollaboratorNamesWithCount() {
    if (collaborators.isEmpty) {
      return (text: organizerName, othersCount: 0);
    }

    final names = [organizerName, ...collaborators.map((c) => c.name)];
    if (names.length == 2) {
      return (text: names.join(' e '), othersCount: 0);
    } else {
      final othersCount = names.length - 2;
      final othersText =
          othersCount == 1 ? 'e 1 altro' : 'e altri $othersCount';
      return (
        text: '${names.first}, ${names[1]} $othersText',
        othersCount: othersCount,
      );
    }
  }

  String _buildCollaboratorClasses() {
    if (collaborators.isEmpty) {
      return organizerClass.isNotEmpty ? organizerClass : 'Studente';
    }

    final classes = <String>{};
    if (organizerClass.isNotEmpty) classes.add(organizerClass);
    for (final c in collaborators) {
      if (c.className.isNotEmpty) classes.add(c.className);
    }

    if (classes.isEmpty) return 'Studenti';
    if (classes.length == 1) return classes.first;
    return classes.take(2).join(' · ');
  }
}
