/// Notification channel types for Nova platform
///
/// Represents the 6 notification channels that students can opt in/out of.
/// Each channel corresponds to a specific user action or system event.
enum NotificationChannel {
  /// Event moderation status updates (approved/rejected)
  ///
  /// Sent to event creators when moderators approve or reject their event.
  /// Maps to database: 'event_moderation'
  /// Preference column: eventi_moderati_enabled
  eventModeration('event_moderation'),

  /// New comment on user's event
  ///
  /// Sent to event creators when someone comments on their event.
  /// Maps to database: 'new_comment'
  /// Preference column: nuovi_commenti_enabled
  newComment('new_comment'),

  /// Reply to user's comment
  ///
  /// Sent to commenters when someone replies to their comment.
  /// Maps to database: 'comment_reply'
  /// Preference column: risposte_commenti_enabled
  commentReply('comment_reply'),

  /// Like on user's event
  ///
  /// Sent to event creators when someone likes their event.
  /// Maps to database: 'event_like'
  /// Preference column: like_eventi_enabled
  eventLike('event_like'),

  /// New participation in user's event
  ///
  /// Sent to event creators when someone joins their event.
  /// Maps to database: 'event_participation'
  /// Preference column: nuove_partecipazioni_enabled
  eventParticipation('event_participation'),

  /// Co-organizer event updates
  ///
  /// Sent to co-organizers when the event they co-organize is edited.
  /// Maps to database: 'coorganizer_update'
  /// Preference column: coorganizer_updates_enabled
  coorganizerUpdate('coorganizer_update');

  /// Database representation of the notification channel
  final String value;

  const NotificationChannel(this.value);

  /// Convert from database string to enum
  ///
  /// Throws [ArgumentError] if [value] doesn't match any channel
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
