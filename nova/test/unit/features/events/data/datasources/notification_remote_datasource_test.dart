import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nova/features/events/data/datasources/notification_remote_datasource.dart';
import 'package:nova/features/events/data/models/notification_model.dart';

import '../../../../../mocks/mock_supabase.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  late NotificationRemoteDataSource dataSource;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQb;

  setUp(() {
    mockSupabase = createMockSupabaseClient(userId: TestUserIds.student1);
    mockQb = MockSupabaseQueryBuilder();

    dataSource = NotificationRemoteDataSource(mockSupabase);
  });

  // ==========================================================================
  // Helper: create notification JSON matching Supabase response
  // ==========================================================================

  Map<String, dynamic> notificationJson({
    String id = 'notif-001',
    String userId = TestUserIds.student1,
    String channel = 'event_approved',
    String title = 'Evento approvato',
    String body = 'Il tuo evento e stato approvato!',
    String? eventId = 'evt-001',
    bool read = false,
    bool delivered = true,
  }) {
    return {
      'id': id,
      'user_id': userId,
      'channel': channel,
      'title': title,
      'body': body,
      'event_id': eventId,
      'sent_at': DateTime.now().toIso8601String(),
      'read': read,
      'delivered': delivered,
    };
  }

  // ==========================================================================
  // getMyNotifications
  // ==========================================================================

  group('getMyNotifications', () {
    test('happy: returns list of NotificationModel', () async {
      final fb = mockListQuery([
        notificationJson(),
        notificationJson(id: 'notif-002', channel: 'event_rejected'),
      ]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result =
          await dataSource.getMyNotifications(TestUserIds.student1);

      expect(result, isA<List<NotificationModel>>());
      expect(result.length, 2);
    });

    test('happy: returns empty list when no notifications', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result =
          await dataSource.getMyNotifications(TestUserIds.student1);

      expect(result, isEmpty);
    });

    test('error: wraps exception in NotificationDataSourceException',
        () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);
      // Override eq to throw after the chain starts
      when(() => fb.eq(any(), any())).thenThrow(Exception('Network error'));

      expect(
        () => dataSource.getMyNotifications(TestUserIds.student1),
        throwsA(isA<NotificationDataSourceException>()),
      );
    });

    test('error: exception message contains original error', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);
      when(() => fb.eq(any(), any())).thenThrow(Exception('timeout'));

      expect(
        () => dataSource.getMyNotifications(TestUserIds.student1),
        throwsA(
          isA<NotificationDataSourceException>().having(
            (e) => e.message,
            'message',
            contains('Failed to fetch notifications'),
          ),
        ),
      );
    });

    test('happy: correctly parses notification fields', () async {
      final json = notificationJson(
        id: 'notif-parse',
        title: 'Titolo Test',
        body: 'Corpo Test',
        read: true,
      );
      final fb = mockListQuery([json]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result =
          await dataSource.getMyNotifications(TestUserIds.student1);

      expect(result.first.id, 'notif-parse');
      expect(result.first.title, 'Titolo Test');
      expect(result.first.body, 'Corpo Test');
      expect(result.first.read, true);
    });
  });

  // ==========================================================================
  // getUnreadCount
  // ==========================================================================

  group('getUnreadCount', () {
    test('happy: returns count of unread notifications', () async {
      final fb = mockListQuery([
        {'id': 'n1'},
        {'id': 'n2'},
        {'id': 'n3'},
      ]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final count = await dataSource.getUnreadCount(TestUserIds.student1);

      expect(count, 3);
    });

    test('happy: returns 0 when all are read', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final count = await dataSource.getUnreadCount(TestUserIds.student1);

      expect(count, 0);
    });

    test('error: wraps exception in NotificationDataSourceException',
        () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);
      when(() => fb.eq(any(), any())).thenThrow(Exception('DB error'));

      expect(
        () => dataSource.getUnreadCount(TestUserIds.student1),
        throwsA(isA<NotificationDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Failed to fetch unread count'),
        )),
      );
    });
  });

  // ==========================================================================
  // getNotificationsByChannel
  // ==========================================================================

  group('getNotificationsByChannel', () {
    test('happy: returns filtered notifications', () async {
      final fb = mockListQuery([
        notificationJson(channel: 'event_approved'),
      ]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getNotificationsByChannel(
        TestUserIds.student1,
        'event_approved',
      );

      expect(result, isA<List<NotificationModel>>());
      expect(result.length, 1);
      expect(result.first.channel, 'event_approved');
    });

    test('happy: returns empty list when no matching channel', () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);

      final result = await dataSource.getNotificationsByChannel(
        TestUserIds.student1,
        'nonexistent_channel',
      );

      expect(result, isEmpty);
    });

    test('error: wraps exception in NotificationDataSourceException',
        () async {
      final fb = mockListQuery([]);
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.select()).thenAnswer((_) => fb);
      when(() => fb.eq(any(), any())).thenThrow(Exception('fail'));

      expect(
        () => dataSource.getNotificationsByChannel(
          TestUserIds.student1,
          'event_approved',
        ),
        throwsA(isA<NotificationDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Failed to fetch notifications by channel'),
        )),
      );
    });
  });

  // ==========================================================================
  // markAsRead
  // ==========================================================================

  group('markAsRead', () {
    test('happy: completes without error', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.markAsRead('notif-001'),
        completes,
      );
    });

    test('happy: calls update with read=true', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.markAsRead('notif-001');

      verify(() => mockQb.update({'read': true})).called(1);
    });

    test('error: wraps exception in NotificationDataSourceException',
        () async {
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenThrow(Exception('RLS denied'));

      expect(
        () => dataSource.markAsRead('notif-001'),
        throwsA(isA<NotificationDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Failed to mark as read'),
        )),
      );
    });
  });

  // ==========================================================================
  // markAllAsRead
  // ==========================================================================

  group('markAllAsRead', () {
    test('happy: completes without error', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await expectLater(
        dataSource.markAllAsRead(TestUserIds.student1),
        completes,
      );
    });

    test('happy: calls update with read=true', () async {
      final fb = mockVoidQuery();
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenAnswer((_) => fb);

      await dataSource.markAllAsRead(TestUserIds.student1);

      verify(() => mockQb.update({'read': true})).called(1);
    });

    test('error: wraps exception in NotificationDataSourceException',
        () async {
      when(() => mockSupabase.from('notifications'))
          .thenAnswer((_) => mockQb);
      when(() => mockQb.update(any())).thenThrow(Exception('fail'));

      expect(
        () => dataSource.markAllAsRead(TestUserIds.student1),
        throwsA(isA<NotificationDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Failed to mark all as read'),
        )),
      );
    });
  });

  // ==========================================================================
  // deleteNotification
  // ==========================================================================

  group('deleteNotification', () {
    test('always throws NotificationDataSourceException (not implemented)',
        () async {
      expect(
        () => dataSource.deleteNotification('notif-001'),
        throwsA(isA<NotificationDataSourceException>().having(
          (e) => e.message,
          'message',
          contains('Delete not implemented'),
        )),
      );
    });
  });

  // ==========================================================================
  // NotificationDataSourceException
  // ==========================================================================

  group('NotificationDataSourceException', () {
    test('toString includes class name and message', () {
      final exception =
          NotificationDataSourceException('test error message');

      expect(
        exception.toString(),
        'NotificationDataSourceException: test error message',
      );
    });

    test('message property is accessible', () {
      final exception = NotificationDataSourceException('my message');

      expect(exception.message, 'my message');
    });
  });
}
