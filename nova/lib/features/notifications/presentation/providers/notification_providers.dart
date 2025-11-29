// Provider: NotificationProviders
// Feature: 008-realtime-notifications
// Purpose: Riverpod providers for notification state management with Supabase Realtime

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository.dart';

// ============================================================================
// DEPENDENCY INJECTION PROVIDERS
// ============================================================================

/// Supabase client provider (re-export for feature isolation)
final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Notification remote datasource provider
final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  final supabase = ref.watch(_supabaseClientProvider);
  return NotificationRemoteDataSource(supabase);
});

/// Notification repository provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(notificationRemoteDataSourceProvider);
  return NotificationRepository(dataSource);
});

// ============================================================================
// STATE PROVIDERS
// ============================================================================

/// Notifications list provider
///
/// Fetches paginated notifications for current user.
/// Use invalidate() to refresh after mutations.
///
/// Usage:
/// ```dart
/// final notificationsAsync = ref.watch(notificationsProvider);
/// notificationsAsync.when(
///   data: (notifications) => ListView.builder(...),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error loading notifications'),
/// );
/// ```
final notificationsProvider = FutureProvider<List<Notification>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return await repository.getNotifications(limit: 100);
});

/// Unread notification count provider
///
/// Returns the count of unread notifications for badge display.
/// Auto-updates via Supabase Realtime subscription.
///
/// Usage:
/// ```dart
/// final count = ref.watch(unreadCountProvider);
/// count.when(
///   data: (count) => count > 0 ? Badge(label: '$count') : null,
///   loading: () => null,
///   error: (_, __) => null,
/// );
/// ```
final unreadCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.subscribeToUnreadCount();
});

/// Real-time notification stream provider
///
/// Emits new notifications as they arrive via Supabase Realtime.
/// Use for in-app notification toasts or live updates.
///
/// Usage:
/// ```dart
/// ref.listen(notificationStreamProvider, (previous, next) {
///   next.whenData((notification) {
///     // Show in-app notification toast
///     showNotificationToast(notification);
///   });
/// });
/// ```
final notificationStreamProvider = StreamProvider<Notification>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.subscribeToNotifications();
});

/// Notification preferences provider
///
/// Loads and caches user notification preferences.
///
/// Usage:
/// ```dart
/// final prefsAsync = ref.watch(notificationPreferencesProvider);
/// prefsAsync.when(
///   data: (prefs) => buildPreferencesUI(prefs),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error loading preferences'),
/// );
/// ```
final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return await repository.getPreferences();
});

// ============================================================================
// STATE NOTIFIER FOR MUTATIONS
// ============================================================================

/// Notification state for NotificationNotifier
class NotificationState {
  final List<Notification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<Notification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notification state notifier for mutations
///
/// Handles mark as read, delete, and other mutations with optimistic UI.
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationNotifier(this._repository, this._ref)
      : super(const NotificationState(isLoading: true)) {
    _loadNotifications();
  }

  /// Load notifications from repository
  Future<void> _loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final notifications = await _repository.getNotifications(limit: 100);
      state = state.copyWith(notifications: notifications, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh notifications
  Future<void> refresh() async {
    await _loadNotifications();
  }

  /// Mark notification as read (optimistic UI)
  Future<void> markAsRead(String notificationId) async {
    // Optimistic update
    final updatedNotifications = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final previousState = state;
    state = state.copyWith(notifications: updatedNotifications);

    try {
      final notification =
          state.notifications.firstWhere((n) => n.id == notificationId);
      await _repository.markAsRead(notification);
      // Invalidate unread count
      _ref.invalidate(unreadCountProvider);
    } catch (e) {
      // Rollback on error
      state = previousState;
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final previousState = state;

    // Optimistic update
    final updatedNotifications =
        state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updatedNotifications);

    try {
      await _repository.markAllAsRead();
      _ref.invalidate(unreadCountProvider);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }

  /// Delete notification (optimistic UI with swipe-to-delete)
  Future<void> deleteNotification(String notificationId) async {
    final previousState = state;

    // Optimistic update
    final updatedNotifications =
        state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updatedNotifications);

    try {
      await _repository.deleteNotification(notificationId);
      _ref.invalidate(unreadCountProvider);
    } catch (e) {
      // Rollback on error
      state = previousState;
      rethrow;
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    final previousState = state;
    state = state.copyWith(notifications: []);

    try {
      await _repository.deleteAllNotifications();
      _ref.invalidate(unreadCountProvider);
    } catch (e) {
      state = previousState;
      rethrow;
    }
  }
}

/// Notification notifier provider
///
/// Usage:
/// ```dart
/// // Read state
/// final state = ref.watch(notificationNotifierProvider);
///
/// // Call mutations
/// final notifier = ref.read(notificationNotifierProvider.notifier);
/// await notifier.markAsRead(notificationId);
/// await notifier.deleteNotification(notificationId);
/// ```
final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(repository, ref);
});

// ============================================================================
// PREFERENCES STATE NOTIFIER
// ============================================================================

/// Preferences state notifier for toggling notification channels
class NotificationPreferencesNotifier
    extends StateNotifier<AsyncValue<NotificationPreferences>> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationPreferencesNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    state = const AsyncValue.loading();
    try {
      final preferences = await _repository.getPreferences();
      state = AsyncValue.data(preferences);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh preferences
  Future<void> refresh() async {
    await _loadPreferences();
  }

  /// Toggle a single preference (optimistic UI)
  Future<void> togglePreference(String columnName, bool value) async {
    final previousState = state;

    // Optimistic update
    state.whenData((prefs) {
      NotificationPreferences updated;
      switch (columnName) {
        case 'eventi_moderati_enabled':
          updated = prefs.copyWith(eventiModeratiEnabled: value);
          break;
        case 'nuovi_commenti_enabled':
          updated = prefs.copyWith(nuoviCommentiEnabled: value);
          break;
        case 'risposte_commenti_enabled':
          updated = prefs.copyWith(risposteCommentiEnabled: value);
          break;
        case 'like_eventi_enabled':
          updated = prefs.copyWith(likeEventiEnabled: value);
          break;
        case 'nuove_partecipazioni_enabled':
          updated = prefs.copyWith(nuovePartecipazioniEnabled: value);
          break;
        case 'coorganizer_updates_enabled':
          updated = prefs.copyWith(coorganizerUpdatesEnabled: value);
          break;
        default:
          return;
      }
      state = AsyncValue.data(updated);
    });

    try {
      await _repository.togglePreference(columnName, value);
    } catch (e, stack) {
      // Rollback on error
      state = previousState;
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

/// Notification preferences notifier provider
///
/// Usage:
/// ```dart
/// // Read state
/// final prefsAsync = ref.watch(notificationPreferencesNotifierProvider);
///
/// // Toggle preference
/// final notifier = ref.read(notificationPreferencesNotifierProvider.notifier);
/// await notifier.togglePreference('nuovi_commenti_enabled', false);
/// ```
final notificationPreferencesNotifierProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, AsyncValue<NotificationPreferences>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationPreferencesNotifier(repository, ref);
});
