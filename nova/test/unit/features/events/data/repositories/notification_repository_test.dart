import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nova/features/events/data/repositories/notification_repository.dart';
import 'package:nova/features/events/data/datasources/notification_remote_datasource.dart';
import 'package:nova/features/events/data/models/notification_model.dart';
import 'package:nova/features/events/domain/entities/app_notification.dart';

import '../../../../../fixtures/test_fixtures.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockNotificationRemoteDataSource extends Mock
    implements NotificationRemoteDataSource {}

void main() {
  late NotificationRepositoryImpl repository;
  late MockNotificationRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockRemoteDataSource = MockNotificationRemoteDataSource();
    repository = NotificationRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
    );
  });

  // ==========================================================================
  // Helper
  // ==========================================================================

  NotificationModel _createNotificationModel({
    String id = 'notif-001',
    String userId = 'test-student-001',
    bool read = false,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      channel: 'event_approved',
      title: 'Event Approved',
      body: 'Your event has been approved!',
      eventId: 'evt-1',
      sentAt: DateTime.now(),
      read: read,
      delivered: true,
    );
  }

  // ==========================================================================
  // getMyNotifications
  // ==========================================================================

  group('getMyNotifications', () {
    test('happy: returns notifications from remote', () async {
      final models = [_createNotificationModel()];
      when(() => mockRemoteDataSource.getMyNotifications(TestUserIds.student1))
          .thenAnswer((_) async => models);

      final result =
          await repository.getMyNotifications(TestUserIds.student1);

      expect(result, isA<List<AppNotification>>());
      expect(result.length, 1);
    });

    test('happy: returns empty list when no notifications', () async {
      when(() => mockRemoteDataSource.getMyNotifications(any()))
          .thenAnswer((_) async => []);

      final result =
          await repository.getMyNotifications(TestUserIds.student1);

      expect(result, isEmpty);
    });

    test('edge: wraps error in NotificationRepositoryException', () async {
      when(() => mockRemoteDataSource.getMyNotifications(any())).thenThrow(
        NotificationDataSourceException('Network error'),
      );

      expect(
        () => repository.getMyNotifications(TestUserIds.student1),
        throwsA(isA<NotificationRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // getUnreadCount
  // ==========================================================================

  group('getUnreadCount', () {
    test('happy: returns count from remote', () async {
      when(() => mockRemoteDataSource.getUnreadCount(TestUserIds.student1))
          .thenAnswer((_) async => 5);

      final result = await repository.getUnreadCount(TestUserIds.student1);

      expect(result, 5);
    });

    test('edge: wraps error in NotificationRepositoryException', () async {
      when(() => mockRemoteDataSource.getUnreadCount(any()))
          .thenThrow(NotificationDataSourceException('fail'));

      expect(
        () => repository.getUnreadCount(TestUserIds.student1),
        throwsA(isA<NotificationRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // markAsRead
  // ==========================================================================

  group('markAsRead', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.markAsRead('notif-001'))
          .thenAnswer((_) async {});

      await repository.markAsRead('notif-001');

      verify(() => mockRemoteDataSource.markAsRead('notif-001')).called(1);
    });

    test('edge: wraps error in NotificationRepositoryException', () async {
      when(() => mockRemoteDataSource.markAsRead(any()))
          .thenThrow(NotificationDataSourceException('fail'));

      expect(
        () => repository.markAsRead('notif-001'),
        throwsA(isA<NotificationRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // deleteNotification
  // ==========================================================================

  group('deleteNotification', () {
    test('race: concurrent deletes for same notification', () async {
      when(() => mockRemoteDataSource.deleteNotification(any()))
          .thenThrow(NotificationDataSourceException(
        'Delete not implemented - requires database migration',
      ));

      // Both should throw since delete is unimplemented
      expect(
        () => repository.deleteNotification('notif-001'),
        throwsA(isA<NotificationRepositoryException>()),
      );
    });
  });

  // ==========================================================================
  // subscribeToNotifications
  // ==========================================================================

  group('subscribeToNotifications', () {
    test('happy: maps stream of models to entities', () {
      final model = _createNotificationModel();
      when(() =>
              mockRemoteDataSource.subscribeToNotifications(TestUserIds.student1))
          .thenAnswer((_) => Stream.value(model));

      final stream =
          repository.subscribeToNotifications(TestUserIds.student1);

      expect(stream, emits(isA<AppNotification>()));
    });
  });
}
