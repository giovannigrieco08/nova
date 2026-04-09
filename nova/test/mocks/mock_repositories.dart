/// Mock repositories for testing
///
/// Provides mocked versions of all repository interfaces
/// using mocktail for unit and widget testing.

import 'package:mocktail/mocktail.dart';
import 'package:nova/features/events/domain/repositories/event_repository_interface.dart';
import 'package:nova/features/events/data/repositories/events_repository.dart';
import 'package:nova/features/events/domain/repositories/notification_repository_interface.dart';
import 'package:nova/features/comments/domain/repositories/comments_repository_interface.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/notifications/domain/repositories/push_repository_interface.dart';

/// Mock EventRepository (interface)
class MockEventRepository extends Mock implements EventRepository {}

/// Mock EventsRepository (concrete data layer)
class MockEventsRepository extends Mock implements EventsRepository {}

/// Mock NotificationRepository (events feature)
class MockNotificationRepository extends Mock
    implements NotificationRepository {}

/// Mock CommentsRepositoryInterface
class MockCommentsRepository extends Mock
    implements CommentsRepositoryInterface {}

/// Mock ChatRepository
class MockChatRepository extends Mock implements ChatRepository {}

/// Mock PushRepository
class MockPushRepository extends Mock implements PushRepository {}
