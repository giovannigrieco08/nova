// Providers: Notification Providers
// Feature: Notifications
// Purpose: Riverpod providers for notification preferences management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification.dart';

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
      risposteCommentiEnabled:
          json['risposte_commenti_enabled'] as bool? ?? true,
      likeEventiEnabled: json['like_eventi_enabled'] as bool? ?? true,
      nuovePartecipazioniEnabled:
          json['nuove_partecipazioni_enabled'] as bool? ?? true,
      coorganizerUpdatesEnabled:
          json['coorganizer_updates_enabled'] as bool? ?? true,
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
}

/// Notification preferences state notifier
class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
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

      // Query profiles table where notification preferences are stored
      final response = await supabase.from('profiles').select('''
            eventi_moderati_enabled,
            nuovi_commenti_enabled,
            risposte_commenti_enabled,
            like_eventi_enabled,
            nuove_partecipazioni_enabled,
            coorganizer_updates_enabled
          ''').eq('user_id', userId).maybeSingle();

      if (response == null) {
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
    final currentPreferences =
        state.valueOrNull ?? const NotificationPreferences();

    // Optimistic update
    final updatedPreferences =
        _updatePreference(currentPreferences, columnName, value);
    state = AsyncValue.data(updatedPreferences);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      // Update preference in profiles table
      await supabase
          .from('profiles')
          .update({columnName: value}).eq('user_id', userId);
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
final notificationPreferencesNotifierProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);

// ============================================================================
// NOTIFICATION LIST PROVIDERS
// ============================================================================

/// Notification list state notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  final SupabaseClient _supabase;
  RealtimeChannel? _realtimeChannel;

  NotificationNotifier(this._supabase) : super(const NotificationState()) {
    // Load notifications on initialization
    loadNotifications();
    // Setup realtime subscription
    _setupRealtimeSubscription();
  }

  /// Setup Supabase Realtime subscription for live notification updates
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            _handleNotificationInsert(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            _handleNotificationUpdate(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            _handleNotificationDelete(payload.oldRecord);
          },
        )
        .subscribe();
  }

  /// Handle new notification insert from Realtime
  void _handleNotificationInsert(Map<String, dynamic> record) {
    try {
      final notification = AppNotification.fromJson(record);
      final updatedList = [notification, ...state.notifications];
      state = state.copyWith(notifications: updatedList);
    } catch (e) {
      // Silently ignore parse errors, will be fetched on next refresh
    }
  }

  /// Handle notification update from Realtime
  void _handleNotificationUpdate(Map<String, dynamic> record) {
    try {
      final updatedNotification = AppNotification.fromJson(record);
      final updatedList = state.notifications.map((n) {
        if (n.id == updatedNotification.id) {
          return updatedNotification;
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updatedList);
    } catch (e) {
      // Silently ignore parse errors
    }
  }

  /// Handle notification delete from Realtime
  void _handleNotificationDelete(Map<String, dynamic> record) {
    final deletedId = record['id'] as String?;
    if (deletedId == null) return;

    final updatedList =
        state.notifications.where((n) => n.id != deletedId).toList();
    state = state.copyWith(notifications: updatedList);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
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
          .select('''
            *,
            actor:profiles!sender_id(
              full_name,
              avatar_url
            )
          ''')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(isLoading: false, notifications: notifications);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento delle notifiche: ${e.toString()}',
      );
    }
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
          .update({'is_read': true}).eq('id', notificationId);
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
    final updated =
        state.notifications.map((n) => n.copyWith(isRead: true)).toList();
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
    final updated =
        state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updated);

    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
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
