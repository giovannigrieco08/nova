// Domain Entity: NotificationChannel
// Feature: Notifications
// Purpose: Enum representing different notification channels with labels and descriptions

/// Notification channels for user preferences
enum NotificationChannel {
  eventModeration(
    label: 'Eventi Moderati',
    description: 'Notifiche quando i tuoi eventi vengono approvati o rifiutati',
  ),
  newComment(
    label: 'Nuovi Commenti',
    description: 'Notifiche quando qualcuno commenta i tuoi eventi',
  ),
  commentReply(
    label: 'Risposte ai Commenti',
    description: 'Notifiche quando qualcuno risponde ai tuoi commenti',
  ),
  eventLike(
    label: 'Like agli Eventi',
    description: 'Notifiche quando qualcuno mette like ai tuoi eventi',
  ),
  eventParticipation(
    label: 'Nuove Partecipazioni',
    description: 'Notifiche quando qualcuno partecipa ai tuoi eventi',
  ),
  coorganizerUpdate(
    label: 'Aggiornamenti Co-organizzatori',
    description: 'Notifiche sugli eventi che co-organizzi',
  ),
  moderatorAlert(
    label: 'Avvisi Moderazione',
    description: 'Notifiche per moderatori su contenuti da revisionare',
  ),
  chatMention(
    label: 'Menzioni in Chat',
    description: 'Notifiche quando qualcuno ti menziona nella chat globale',
  );

  const NotificationChannel({
    required this.label,
    required this.description,
  });

  /// Italian label for UI display
  final String label;

  /// Italian description for UI display
  final String description;
}
