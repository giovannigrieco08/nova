// =====================================================================
// Notifications Data Providers - Push Notifications Feature (009)
// =====================================================================
// Purpose: Data layer dependency injection providers
// =====================================================================

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../domain/repositories/push_repository_interface.dart';
import '../datasources/fcm_token_remote_datasource.dart';
import '../repositories/push_repository.dart';

// ============================================================================
// DEPENDENCY INJECTION PROVIDERS
// ============================================================================

/// Supabase client provider (re-export for feature isolation)
final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Firebase Messaging instance provider
final _firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

/// Flutter Local Notifications plugin provider
final _localNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

/// FCM token remote datasource provider
final fcmTokenRemoteDataSourceProvider =
    Provider<FcmTokenRemoteDataSource>((ref) {
  final supabase = ref.watch(_supabaseClientProvider);
  return FcmTokenRemoteDataSource(supabase);
});

/// Push repository provider
final pushRepositoryProvider = Provider<PushRepository>((ref) {
  final dataSource = ref.watch(fcmTokenRemoteDataSourceProvider);
  return PushRepositoryImpl(dataSource);
});

/// Push notification service provider
///
/// Usage:
/// ```dart
/// final pushService = ref.read(pushNotificationServiceProvider);
/// await pushService.initialize();
/// await pushService.registerToken();
/// ```
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final messaging = ref.watch(_firebaseMessagingProvider);
  final localNotifications = ref.watch(_localNotificationsProvider);
  final repository = ref.watch(pushRepositoryProvider);

  return PushNotificationService(
    messaging: messaging,
    localNotifications: localNotifications,
    repository: repository,
  );
});
