/// Notification channel types for Nova platform
///
/// Represents the 6 notification channels that students can opt in/out of.
/// Each channel corresponds to a specific user action or system event.
enum NotificationChannel {
  /// Event moderation status updates (approved/rejected)
  eventModeration('event_moderation'),

  /// New comment on user's event
  newComment('new_comment'),

  /// Reply to user's comment
  commentReply('comment_reply'),

  /// Like on user's event
  eventLike('event_like'),

  /// New participation in user's event
  eventParticipation('event_participation'),

  /// Co-organizer event updates
  coorganizerUpdate('coorganizer_update');

  /// Database representation of the notification channel
  final String value;

  const NotificationChannel(this.value);

  /// Convert from database string to enum
  static NotificationChannel fromString(String value) {
    return NotificationChannel.values.firstWhere(
      (channel) => channel.value == value,
      orElse: () => throw ArgumentError('Invalid notification channel: $value'),
    );
  }

  /// Human-readable label for UI display (Italian)
  String get label {
    switch (this) {
      case NotificationChannel.eventModeration:
        return 'Eventi moderati';
      case NotificationChannel.newComment:
        return 'Nuovi commenti';
      case NotificationChannel.commentReply:
        return 'Risposte ai commenti';
      case NotificationChannel.eventLike:
        return 'Like agli eventi';
      case NotificationChannel.eventParticipation:
        return 'Nuove partecipazioni';
      case NotificationChannel.coorganizerUpdate:
        return 'Aggiornamenti co-organizer';
    }
  }

  /// Short description for settings screen (Italian)
  String get description {
    switch (this) {
      case NotificationChannel.eventModeration:
        return 'Ricevi notifiche quando i tuoi eventi vengono approvati o rifiutati';
      case NotificationChannel.newComment:
        return 'Ricevi notifiche quando qualcuno commenta i tuoi eventi';
      case NotificationChannel.commentReply:
        return 'Ricevi notifiche quando qualcuno risponde ai tuoi commenti';
      case NotificationChannel.eventLike:
        return 'Ricevi notifiche quando qualcuno mette like ai tuoi eventi';
      case NotificationChannel.eventParticipation:
        return 'Ricevi notifiche quando qualcuno partecipa ai tuoi eventi';
      case NotificationChannel.coorganizerUpdate:
        return 'Ricevi notifiche quando un evento che co-organizzi viene modificato';
    }
  }
}
