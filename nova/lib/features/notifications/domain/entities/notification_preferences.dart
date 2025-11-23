/// Notification preferences entity
///
/// Represents user preferences for each of the 6 notification channels.
/// All channels are enabled by default (opt-out model per constitutional requirements).
class NotificationPreferences {
  /// Enable/disable event moderation notifications
  ///
  /// When enabled, user receives notifications when their events are approved/rejected.
  /// Default: true (opt-out model)
  final bool eventiModeratiEnabled;

  /// Enable/disable new comment notifications
  ///
  /// When enabled, user receives notifications when someone comments on their events.
  /// Default: true (opt-out model)
  final bool nuoviCommentiEnabled;

  /// Enable/disable comment reply notifications
  ///
  /// When enabled, user receives notifications when someone replies to their comments.
  /// Default: true (opt-out model)
  final bool risposteCommentiEnabled;

  /// Enable/disable event like notifications
  ///
  /// When enabled, user receives notifications when someone likes their events.
  /// Default: true (opt-out model)
  final bool likeEventiEnabled;

  /// Enable/disable event participation notifications
  ///
  /// When enabled, user receives notifications when someone joins their events.
  /// Default: true (opt-out model)
  final bool nuovePartecipazioniEnabled;

  /// Enable/disable co-organizer update notifications
  ///
  /// When enabled, user receives notifications when events they co-organize are edited.
  /// Default: true (opt-out model)
  final bool coorganizerUpdatesEnabled;

  const NotificationPreferences({
    this.eventiModeratiEnabled = true,
    this.nuoviCommentiEnabled = true,
    this.risposteCommentiEnabled = true,
    this.likeEventiEnabled = true,
    this.nuovePartecipazioniEnabled = true,
    this.coorganizerUpdatesEnabled = true,
  });

  /// Default preferences with all channels enabled
  ///
  /// Used for new users or when preferences are not yet set
  static const NotificationPreferences defaults = NotificationPreferences();

  /// Create a copy with modified fields
  ///
  /// Used for optimistic UI updates when toggling preferences
  NotificationPreferences copyWith({
    bool? eventiModeratiEnabled,
    bool? nuoviCommentiEnabled,
    bool? risposteCommentiEnabled,
    bool? likeEventiEnabled,
    bool? nuovePartecipazioniEnabled,
    bool? coorganizerUpdatesEnabled,
  }) {
    return NotificationPreferences(
      eventiModeratiEnabled:
          eventiModeratiEnabled ?? this.eventiModeratiEnabled,
      nuoviCommentiEnabled: nuoviCommentiEnabled ?? this.nuoviCommentiEnabled,
      risposteCommentiEnabled:
          risposteCommentiEnabled ?? this.risposteCommentiEnabled,
      likeEventiEnabled: likeEventiEnabled ?? this.likeEventiEnabled,
      nuovePartecipazioniEnabled:
          nuovePartecipazioniEnabled ?? this.nuovePartecipazioniEnabled,
      coorganizerUpdatesEnabled:
          coorganizerUpdatesEnabled ?? this.coorganizerUpdatesEnabled,
    );
  }

  /// Check if any notification channel is enabled
  bool get hasAnyEnabled =>
      eventiModeratiEnabled ||
      nuoviCommentiEnabled ||
      risposteCommentiEnabled ||
      likeEventiEnabled ||
      nuovePartecipazioniEnabled ||
      coorganizerUpdatesEnabled;

  /// Check if all notification channels are enabled
  bool get hasAllEnabled =>
      eventiModeratiEnabled &&
      nuoviCommentiEnabled &&
      risposteCommentiEnabled &&
      likeEventiEnabled &&
      nuovePartecipazioniEnabled &&
      coorganizerUpdatesEnabled;

  /// Count of enabled notification channels (0-6)
  int get enabledCount =>
      (eventiModeratiEnabled ? 1 : 0) +
      (nuoviCommentiEnabled ? 1 : 0) +
      (risposteCommentiEnabled ? 1 : 0) +
      (likeEventiEnabled ? 1 : 0) +
      (nuovePartecipazioniEnabled ? 1 : 0) +
      (coorganizerUpdatesEnabled ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          runtimeType == other.runtimeType &&
          eventiModeratiEnabled == other.eventiModeratiEnabled &&
          nuoviCommentiEnabled == other.nuoviCommentiEnabled &&
          risposteCommentiEnabled == other.risposteCommentiEnabled &&
          likeEventiEnabled == other.likeEventiEnabled &&
          nuovePartecipazioniEnabled == other.nuovePartecipazioniEnabled &&
          coorganizerUpdatesEnabled == other.coorganizerUpdatesEnabled;

  @override
  int get hashCode =>
      eventiModeratiEnabled.hashCode ^
      nuoviCommentiEnabled.hashCode ^
      risposteCommentiEnabled.hashCode ^
      likeEventiEnabled.hashCode ^
      nuovePartecipazioniEnabled.hashCode ^
      coorganizerUpdatesEnabled.hashCode;

  @override
  String toString() {
    return 'NotificationPreferences{eventiModeratiEnabled: $eventiModeratiEnabled, nuoviCommentiEnabled: $nuoviCommentiEnabled, risposteCommentiEnabled: $risposteCommentiEnabled, likeEventiEnabled: $likeEventiEnabled, nuovePartecipazioniEnabled: $nuovePartecipazioniEnabled, coorganizerUpdatesEnabled: $coorganizerUpdatesEnabled}';
  }
}
