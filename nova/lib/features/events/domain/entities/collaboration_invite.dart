// =====================================================================
// CollaborationInvite Entity - Feature 004 (Collaborative Events)
// =====================================================================
// Purpose: Tracks invitations to collaborate on event creation
// Status: pending → accepted/declined
// =====================================================================

/// Status of a collaboration invite
enum CollaborationInviteStatus {
  /// Invite sent, waiting for response
  pending,

  /// Invite accepted, user is now a collaborator
  accepted,

  /// Invite declined by the invitee
  declined,

  /// Invite expired (not responded within time limit)
  expired,
}

/// Collaboration invite entity
///
/// Represents an invitation to collaborate on an event.
/// The invitee must accept before being listed as a co-organizer.
class CollaborationInvite {
  /// Unique invite ID (UUID)
  final String id;

  /// Event ID this invite is for
  final String eventId;

  /// User ID who sent the invite (event creator)
  final String inviterId;

  /// User ID who received the invite
  final String inviteeId;

  /// Current status of the invite
  final CollaborationInviteStatus status;

  /// When the invite was created
  final DateTime createdAt;

  /// When the invite was responded to (accepted/declined)
  final DateTime? respondedAt;

  /// Optional message from inviter
  final String? message;

  const CollaborationInvite({
    required this.id,
    required this.eventId,
    required this.inviterId,
    required this.inviteeId,
    this.status = CollaborationInviteStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.message,
  });

  /// Check if invite is pending
  bool get isPending => status == CollaborationInviteStatus.pending;

  /// Check if invite was accepted
  bool get isAccepted => status == CollaborationInviteStatus.accepted;

  /// Check if invite was declined
  bool get isDeclined => status == CollaborationInviteStatus.declined;

  /// Create from JSON
  factory CollaborationInvite.fromJson(Map<String, dynamic> json) {
    return CollaborationInvite(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      inviterId: json['inviter_id'] as String,
      inviteeId: json['invitee_id'] as String,
      status: CollaborationInviteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CollaborationInviteStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      message: json['message'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
      if (message != null) 'message': message,
    };
  }

  /// Copy with updated fields
  CollaborationInvite copyWith({
    String? id,
    String? eventId,
    String? inviterId,
    String? inviteeId,
    CollaborationInviteStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return CollaborationInvite(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      inviterId: inviterId ?? this.inviterId,
      inviteeId: inviteeId ?? this.inviteeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
    );
  }

  @override
  String toString() {
    return 'CollaborationInvite(id: $id, eventId: $eventId, inviteeId: $inviteeId, status: $status)';
  }
}
