import '../../domain/entities/notification_preferences.dart';

/// Data model for NotificationPreferences with Supabase JSON serialization
///
/// Maps to the 6 preference columns on the profiles table
class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    super.eventiModeratiEnabled,
    super.nuoviCommentiEnabled,
    super.risposteCommentiEnabled,
    super.likeEventiEnabled,
    super.nuovePartecipazioniEnabled,
    super.coorganizerUpdatesEnabled,
  });

  /// Create from Supabase profiles JSON response
  ///
  /// Extracts only the notification preference columns
  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      eventiModeratiEnabled: json['eventi_moderati_enabled'] as bool? ?? true,
      nuoviCommentiEnabled: json['nuovi_commenti_enabled'] as bool? ?? true,
      risposteCommentiEnabled: json['risposte_commenti_enabled'] as bool? ?? true,
      likeEventiEnabled: json['like_eventi_enabled'] as bool? ?? true,
      nuovePartecipazioniEnabled: json['nuove_partecipazioni_enabled'] as bool? ?? true,
      coorganizerUpdatesEnabled: json['coorganizer_updates_enabled'] as bool? ?? true,
    );
  }

  /// Convert to JSON for Supabase PATCH request
  ///
  /// Only includes the preference columns (not the full profile)
  Map<String, dynamic> toJson() {
    return {
      'eventi_moderati_enabled': eventiModeratiEnabled,
      'nuovi_commenti_enabled': nuoviCommentiEnabled,
      'risposte_commenti_enabled': risposteCommentiEnabled,
      'like_eventi_enabled': likeEventiEnabled,
      'nuove_partecipazioni_enabled': nuovePartecipazioniEnabled,
      'coorganizer_updates_enabled': coorganizerUpdatesEnabled,
    };
  }

  /// Create from domain entity
  factory NotificationPreferencesModel.fromEntity(NotificationPreferences entity) {
    return NotificationPreferencesModel(
      eventiModeratiEnabled: entity.eventiModeratiEnabled,
      nuoviCommentiEnabled: entity.nuoviCommentiEnabled,
      risposteCommentiEnabled: entity.risposteCommentiEnabled,
      likeEventiEnabled: entity.likeEventiEnabled,
      nuovePartecipazioniEnabled: entity.nuovePartecipazioniEnabled,
      coorganizerUpdatesEnabled: entity.coorganizerUpdatesEnabled,
    );
  }

  /// Convert to domain entity
  NotificationPreferences toEntity() {
    return NotificationPreferences(
      eventiModeratiEnabled: eventiModeratiEnabled,
      nuoviCommentiEnabled: nuoviCommentiEnabled,
      risposteCommentiEnabled: risposteCommentiEnabled,
      likeEventiEnabled: likeEventiEnabled,
      nuovePartecipazioniEnabled: nuovePartecipazioniEnabled,
      coorganizerUpdatesEnabled: coorganizerUpdatesEnabled,
    );
  }

  @override
  NotificationPreferencesModel copyWith({
    bool? eventiModeratiEnabled,
    bool? nuoviCommentiEnabled,
    bool? risposteCommentiEnabled,
    bool? likeEventiEnabled,
    bool? nuovePartecipazioniEnabled,
    bool? coorganizerUpdatesEnabled,
  }) {
    return NotificationPreferencesModel(
      eventiModeratiEnabled: eventiModeratiEnabled ?? this.eventiModeratiEnabled,
      nuoviCommentiEnabled: nuoviCommentiEnabled ?? this.nuoviCommentiEnabled,
      risposteCommentiEnabled: risposteCommentiEnabled ?? this.risposteCommentiEnabled,
      likeEventiEnabled: likeEventiEnabled ?? this.likeEventiEnabled,
      nuovePartecipazioniEnabled: nuovePartecipazioniEnabled ?? this.nuovePartecipazioniEnabled,
      coorganizerUpdatesEnabled: coorganizerUpdatesEnabled ?? this.coorganizerUpdatesEnabled,
    );
  }
}
