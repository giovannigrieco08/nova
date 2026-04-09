import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:nova/features/notifications/domain/entities/notification.dart';
import 'package:nova/features/notifications/domain/entities/notification_channel.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late NotificationRemoteDataSource datasource;

  const testUserId = 'user-123';

  setUpAll(() {
    ensureMockFallbacks();
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockUser.id).thenReturn(testUserId);
    when(() => mockUser.email).thenReturn('test@galileimoro.edu.it');
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockClient.auth).thenReturn(mockAuth);

    datasource = NotificationRemoteDataSource(mockClient);
  });

  // Sample notification JSON matching the database schema
  Map<String, dynamic> makeNotificationJson({
    String id = 'notif-1',
    String type = 'new_comment',
    String title = 'Nuovo commento',
    String description = 'Mario ha commentato il tuo evento',
    bool isRead = false,
    String? senderId,
    Map<String, dynamic>? actor,
  }) {
    return {
      'id': id,
      'recipient_id': testUserId,
      'type': type,
      'title': title,
      'description': description,
      'is_read': isRead,
      'created_at': '2025-06-01T12:00:00.000Z',
      'sender_id': senderId ?? 'sender-1',
      'actor': actor,
      'target_type': null,
      'target_id': null,
      'metadata': null,
    };
  }

  // ==========================================================================
  // getNotifications
  // ==========================================================================

  group('getNotifications', () {
    test('returns list of notifications for authenticated user', () async {
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockClient.from('notifications')).thenAnswer((_) => mockQb);

      final fb = mockListQuery([
        makeNotificationJson(id: 'n-1'),
        makeNotificationJson(id: 'n-2', isRead: true),
      ]);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await datasource.getNotifications();

      expect(result, hasLength(2));
      expect(result[0].id, 'n-1');
      expect(result[1].id, 'n-2');
      expect(result[0].isRead, isFalse);
      expect(result[1].isRead, isTrue);
    });

    test('returns empty list when user is not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final result = await datasource.getNotifications();

      expect(result, isEmpty);
    });

    test('respects custom limit parameter', () async {
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockClient.from('notifications')).thenAnswer((_) => mockQb);

      final fb = mockListQuery([makeNotificationJson()]);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await datasource.getNotifications(limit: 10);

      expect(result, hasLength(1));
    });

    test('parses actor profile from joined data', () async {
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockClient.from('notifications')).thenAnswer((_) => mockQb);

      final fb = mockListQuery([
        makeNotificationJson(
          id: 'n-1',
          senderId: 'actor-1',
          actor: {
            'full_name': 'Mario Rossi',
            'avatar_url': 'https://example.com/avatar.png',
          },
        ),
      ]);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await datasource.getNotifications();

      expect(result, hasLength(1));
      expect(result[0].actorName, 'Mario Rossi');
      expect(result[0].actorAvatarUrl, 'https://example.com/avatar.png');
      expect(result[0].actorId, 'actor-1');
    });
  });

  // ==========================================================================
  // markAsRead
  // ==========================================================================

  group('markAsRead', () {
    test('calls update on notifications table', () async {
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockClient.from('notifications')).thenAnswer((_) => mockQb);

      final fb = mockVoidQuery();
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      // Should complete without error
      await datasource.markAsRead('notif-1');
    });
  });

  // ==========================================================================
  // markAllAsRead
  // ==========================================================================

  group('markAllAsRead', () {
    test('calls update on notifications table for user', () async {
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockClient.from('notifications')).thenAnswer((_) => mockQb);

      final fb = mockVoidQuery();
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      // Should complete without error
      await datasource.markAllAsRead();
    });

    test('does nothing when user is not authenticated', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      await datasource.markAllAsRead();

      verifyNever(() => mockClient.from(any()));
    });
  });

  // ==========================================================================
  // deleteNotification
  // ==========================================================================

  group('deleteNotification', () {
    test('calls delete on notifications table', () async {
      final mockQb = MockSupabaseQueryBuilder();
      when(() => mockClient.from('notifications')).thenAnswer((_) => mockQb);

      final fb = mockVoidQuery();
      when(() => mockQb.delete()).thenAnswer((_) => fb);

      // Should complete without error
      await datasource.deleteNotification('notif-1');
    });
  });
}
