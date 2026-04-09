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

/// Help request info for display in EventCard.
/// Contains minimal data needed for UI display and sheet opening.
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
