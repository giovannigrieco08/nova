/// Notification preferences entity
///
/// Represents user preferences for each of the 6 notification channels.
/// All channels are enabled by default (opt-out model per constitutional requirements).
class NotificationPreferences {
  final bool eventiModeratiEnabled;
  final bool nuoviCommentiEnabled;
  final bool risposteCommentiEnabled;
  final bool likeEventiEnabled;
  final bool nuovePartecipazioniEnabled;
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
  static const NotificationPreferences defaults = NotificationPreferences();

  /// Create a copy with modified fields
  NotificationPreferences copyWith({
    bool? eventiModeratiEnabled,
    bool? nuoviCommentiEnabled,
    bool? risposteCommentiEnabled,
    bool? likeEventiEnabled,
    bool? nuovePartecipazioniEnabled,
    bool? coorganizerUpdatesEnabled,
  }) {
    return NotificationPreferences(
      eventiModeratiEnabled: eventiModeratiEnabled ?? this.eventiModeratiEnabled,
      nuoviCommentiEnabled: nuoviCommentiEnabled ?? this.nuoviCommentiEnabled,
      risposteCommentiEnabled: risposteCommentiEnabled ?? this.risposteCommentiEnabled,
      likeEventiEnabled: likeEventiEnabled ?? this.likeEventiEnabled,
      nuovePartecipazioniEnabled: nuovePartecipazioniEnabled ?? this.nuovePartecipazioniEnabled,
      coorganizerUpdatesEnabled: coorganizerUpdatesEnabled ?? this.coorganizerUpdatesEnabled,
    );
  }

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
}
