import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/notifications/domain/usecases/handle_push_tap.dart';
import 'package:nova/features/notifications/domain/entities/push_payload.dart';
import 'package:nova/features/notifications/data/repositories/notification_repository.dart';

class MockNotificationRepo extends Mock implements NotificationRepository {}

void main() {
  late HandlePushTap useCase;
  late MockNotificationRepo mockRepository;

  setUp(() {
    mockRepository = MockNotificationRepo();
    useCase = HandlePushTap(mockRepository);
  });

  PushPayload createPayload({
    String targetType = 'event',
    String targetId = 'target-001',
    String notificationId = 'notif-001',
    String? eventId,
  }) {
    return PushPayload(
      title: 'Test Notification',
      body: 'Test body',
      targetType: targetType,
      targetId: targetId,
      notificationId: notificationId,
      badgeCount: 1,
      eventId: eventId,
    );
  }

  group('HandlePushTap', () {
    // ===== HAPPY PATH TESTS =====

    test('navigates to event and marks notification as read', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenAnswer((_) async => {});

      final payload = createPayload(
        targetType: 'event',
        targetId: 'event-123',
      );

      final result = await useCase.execute(payload);

      expect(result.type, equals(PushNavigationType.event));
      expect(result.eventId, equals('event-123'));
      expect(result.isValid, isTrue);
      verify(() => mockRepository.markAsRead('notif-001')).called(1);
    });

    test('navigates to comment with eventId from payload', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenAnswer((_) async => {});

      final payload = createPayload(
        targetType: 'comment',
        targetId: 'comment-456',
        eventId: 'event-789',
      );

      final result = await useCase.execute(payload);

      expect(result.type, equals(PushNavigationType.comment));
      expect(result.eventId, equals('event-789'));
      expect(result.commentId, equals('comment-456'));
      expect(result.isValid, isTrue);
    });

    test('navigates to profile screen', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenAnswer((_) async => {});

      final payload = createPayload(
        targetType: 'profile',
        targetId: 'user-001',
      );

      final result = await useCase.execute(payload);

      expect(result.type, equals(PushNavigationType.profile));
      expect(result.userId, equals('user-001'));
      expect(result.isValid, isTrue);
    });

    test('navigates to chat screen with optional messageId', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenAnswer((_) async => {});

      final payload = createPayload(
        targetType: 'chat',
        targetId: 'msg-001',
      );

      final result = await useCase.execute(payload);

      expect(result.type, equals(PushNavigationType.chat));
      expect(result.messageId, equals('msg-001'));
      expect(result.isValid, isTrue);
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('returns error result for unknown target type', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenAnswer((_) async => {});

      final payload = createPayload(
        targetType: 'unknown_type',
        targetId: 'id-001',
      );

      final result = await useCase.execute(payload);

      expect(result.type, equals(PushNavigationType.unknown));
      expect(result.isValid, isFalse);
      expect(result.error, contains('Unknown target type'));
    });

    test('returns error when event target has empty targetId', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenAnswer((_) async => {});

      final payload = createPayload(
        targetType: 'event',
        targetId: '',
      );

      final result = await useCase.execute(payload);

      expect(result.isValid, isFalse);
      expect(result.error, equals('Event ID missing'));
    });

    test('continues navigation even when markAsRead fails', () async {
      when(() => mockRepository.markAsRead(any()))
          .thenThrow(Exception('Network error'));

      final payload = createPayload(
        targetType: 'event',
        targetId: 'event-123',
      );

      final result = await useCase.execute(payload);

      expect(result.type, equals(PushNavigationType.event));
      expect(result.eventId, equals('event-123'));
      expect(result.isValid, isTrue);
    });
  });
}
