/// Mock services for testing
///
/// Provides mocked versions of core services
/// using mocktail for unit and widget testing.

import 'package:mocktail/mocktail.dart';
import 'package:nova/core/services/push_notification_service.dart';
import 'package:nova/core/services/error_handler_service.dart';
import 'package:nova/core/services/share_service.dart';
import 'package:nova/core/services/deep_link_service.dart';
import 'package:nova/core/services/notification_service.dart';

/// Mock PushNotificationService
class MockPushNotificationService extends Mock
    implements PushNotificationService {}

/// Mock ErrorHandlerService
class MockErrorHandlerService extends Mock implements ErrorHandlerService {}

/// Mock ShareService
class MockShareService extends Mock implements ShareService {}

/// Mock DeepLinkService
class MockDeepLinkService extends Mock implements DeepLinkService {}

/// Mock NotificationService
class MockNotificationService extends Mock implements NotificationService {}
