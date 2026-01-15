// Providers: Notification Providers
// Feature: Notifications
// Purpose: Riverpod providers for notification preferences management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/notification_channel.dart';

/// Notification preferences model
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

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      eventiModeratiEnabled: json['eventi_moderati_enabled'] as bool? ?? true,
      nuoviCommentiEnabled: json['nuovi_commenti_enabled'] as bool? ?? true,
      risposteCommentiEnabled: json['risposte_commenti_enabled'] as bool? ?? true,
      likeEventiEnabled: json['like_eventi_enabled'] as bool? ?? true,
      nuovePartecipazioniEnabled: json['nuove_partecipazioni_enabled'] as bool? ?? true,
      coorganizerUpdatesEnabled: json['coorganizer_updates_enabled'] as bool? ?? true,
    );
  }

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
}

/// Notification preferences state notifier
class NotificationPreferencesNotifier extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    return _loadPreferences();
  }

  Future<NotificationPreferences> _loadPreferences() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        return const NotificationPreferences();
      }

      final response = await supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create default preferences if not exists
        return const NotificationPreferences();
      }

      return NotificationPreferences.fromJson(response);
    } catch (e) {
      // Return defaults on error
      return const NotificationPreferences();
    }
  }

  /// Refresh preferences from server
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPreferences());
  }

  /// Toggle a specific preference
  Future<void> togglePreference(String columnName, bool value) async {
    final currentPreferences = state.valueOrNull ?? const NotificationPreferences();

    // Optimistic update
    final updatedPreferences = _updatePreference(currentPreferences, columnName, value);
    state = AsyncValue.data(updatedPreferences);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      await supabase.from('notification_preferences').upsert({
        'user_id': userId,
        columnName: value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentPreferences);
      rethrow;
    }
  }

  NotificationPreferences _updatePreference(
    NotificationPreferences prefs,
    String columnName,
    bool value,
  ) {
    switch (columnName) {
      case 'eventi_moderati_enabled':
        return prefs.copyWith(eventiModeratiEnabled: value);
      case 'nuovi_commenti_enabled':
        return prefs.copyWith(nuoviCommentiEnabled: value);
      case 'risposte_commenti_enabled':
        return prefs.copyWith(risposteCommentiEnabled: value);
      case 'like_eventi_enabled':
        return prefs.copyWith(likeEventiEnabled: value);
      case 'nuove_partecipazioni_enabled':
        return prefs.copyWith(nuovePartecipazioniEnabled: value);
      case 'coorganizer_updates_enabled':
        return prefs.copyWith(coorganizerUpdatesEnabled: value);
      default:
        return prefs;
    }
  }
}

/// Provider for notification preferences
final notificationPreferencesNotifierProvider =
    AsyncNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);

// ============================================================================
// NOTIFICATION LIST PROVIDERS
// ============================================================================

/// Notification list state notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  final SupabaseClient _supabase;

  NotificationNotifier(this._supabase) : super(const NotificationState()) {
    // Load notifications on initialization
    loadNotifications();
  }

  /// Load notifications from Supabase
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(isLoading: false, notifications: []);
        return;
      }

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      var notifications = (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      // ========== MOCK DATA FOR UI TESTING ==========
      // TODO: Remove this mock data after testing
      if (notifications.isEmpty) {
        notifications = _getMockNotifications(userId);
      }
      // ========== END MOCK DATA ==========

      state = state.copyWith(isLoading: false, notifications: notifications);
    } catch (e) {
      // If table doesn't exist yet (migration not applied), show mock data
      final errorStr = e.toString();
      if (errorStr.contains('does not exist') || errorStr.contains('42P01') || errorStr.contains('42703')) {
        final userId = _supabase.auth.currentUser?.id ?? 'mock-user';
        state = state.copyWith(
          isLoading: false,
          notifications: _getMockNotifications(userId),
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento delle notifiche: ${e.toString()}',
      );
    }
  }

  /// Generate mock notifications for UI testing
  List<AppNotification> _getMockNotifications(String userId) {
    final now = DateTime.now();
    return [
      // Unread - Event approved (system notification, no actor)
      AppNotification(
        id: 'mock-1',
        userId: userId,
        channel: NotificationChannel.eventModeration,
        title: 'approvato',
        body: 'Il tuo evento "Torneo di Calcetto" è stato approvato ed è ora visibile nel feed.',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
        data: {'target_type': 'event', 'target_id': 'event-123'},
        actorName: 'Nova',
      ),
      // Unread - Chat mention
      AppNotification(
        id: 'mock-2',
        userId: userId,
        channel: NotificationChannel.chatMention,
        title: 'ti ha menzionato nella chat',
        body: '@tu sei libero domani per lo studio di gruppo?',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 15)),
        data: {'target_type': 'chat_mention'},
        actorName: 'Marco Bianchi',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=marco',
      ),
      // Unread - New comment
      AppNotification(
        id: 'mock-3',
        userId: userId,
        channel: NotificationChannel.newComment,
        title: 'ha commentato il tuo evento',
        body: '"Fantastico! Ci sarò sicuramente!"',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 1)),
        data: {'target_type': 'comment', 'event_id': 'event-123', 'target_id': 'comment-456'},
        actorName: 'Sofia Romano',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=sofia',
      ),
      // Unread - Event like
      AppNotification(
        id: 'mock-4',
        userId: userId,
        channel: NotificationChannel.eventLike,
        title: 'ha messo like al tuo evento',
        body: '"Torneo di Calcetto"',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        data: {'target_type': 'event', 'target_id': 'event-123'},
        actorName: 'Giulia Verdi',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=giulia',
      ),
      // Unread - New participation
      AppNotification(
        id: 'mock-5',
        userId: userId,
        channel: NotificationChannel.eventParticipation,
        title: 'parteciperà al tuo evento',
        body: '"Studio di Gruppo Matematica"',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3)),
        data: {'target_type': 'event', 'target_id': 'event-456'},
        actorName: 'Andrea Rossi',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=andrea',
      ),
      // Read - Comment reply (ieri)
      AppNotification(
        id: 'mock-6',
        userId: userId,
        channel: NotificationChannel.commentReply,
        title: 'ha risposto al tuo commento',
        body: '"Perfetto, ci vediamo alle 15!"',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        data: {'target_type': 'comment', 'event_id': 'event-789', 'target_id': 'comment-789'},
        actorName: 'Luca Neri',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=luca',
      ),
      // Read - Co-organizer update (ieri)
      AppNotification(
        id: 'mock-7',
        userId: userId,
        channel: NotificationChannel.coorganizerUpdate,
        title: 'ha modificato l\'evento',
        body: '"Sessione di Studio"',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        data: {'target_type': 'event', 'target_id': 'event-789'},
        actorName: 'Marco Bianchi',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=marco',
      ),
      // Read - Event rejected (ultimi 7 giorni)
      AppNotification(
        id: 'mock-8',
        userId: userId,
        channel: NotificationChannel.eventModeration,
        title: 'non approvato',
        body: 'Il tuo evento "Festa in Spiaggia" non è stato approvato. Motivo: località non idonea.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 3)),
        data: {'target_type': 'event', 'target_id': 'event-rejected'},
        actorName: 'Nova',
      ),
      // Read - Multiple likes (ultimi 7 giorni)
      AppNotification(
        id: 'mock-9',
        userId: userId,
        channel: NotificationChannel.eventLike,
        title: 'e altri 2 hanno messo like',
        body: 'al tuo evento "Cineforum Venerdì"',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 4)),
        data: {'target_type': 'event', 'target_id': 'event-cinema'},
        actorName: 'Elena',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=elena',
      ),
      // Read - Old participation (ultimi 7 giorni)
      AppNotification(
        id: 'mock-10',
        userId: userId,
        channel: NotificationChannel.eventParticipation,
        title: 'e altri 4 parteciperanno',
        body: 'al tuo evento "Torneo di Calcetto"',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 5)),
        data: {'target_type': 'event', 'target_id': 'event-123'},
        actorName: 'Maria',
        actorAvatarUrl: 'https://i.pravatar.cc/150?u=maria',
      ),
    ];
  }

  /// Refresh notifications
  Future<void> refresh() async {
    await loadNotifications();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    // Optimistic update
    final updated = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      // Revert on error
      await loadNotifications();
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Optimistic update
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (e) {
      // Revert on error
      await loadNotifications();
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    // Optimistic update
    final updated = state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updated);

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      // Revert on error
      await loadNotifications();
    }
  }
}

/// Provider for notification list
final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(Supabase.instance.client),
);

/// Provider for unread notification count
final unreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationNotifierProvider);
  return state.notifications.where((n) => !n.isRead).length;
});
