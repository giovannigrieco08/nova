// Notifications feature barrel export
//
// Import this file to access all notifications feature components:
// import 'package:nova/features/notifications/notifications.dart';

// Domain entities
export 'domain/entities/notification.dart';
export 'domain/entities/notification_channel.dart';
export 'domain/entities/notification_preferences.dart';

// Data layer
export 'data/models/notification_model.dart';
export 'data/models/notification_preferences_model.dart';
export 'data/datasources/notification_remote_datasource.dart';
export 'data/repositories/notification_repository.dart';

// Presentation - Providers
export 'presentation/providers/notification_providers.dart';

// Presentation - Screens
export 'presentation/screens/notification_list_screen.dart';
export 'presentation/screens/notification_preferences_screen.dart';

// Presentation - Widgets
export 'presentation/widgets/notification_badge.dart';
export 'presentation/widgets/notification_tile.dart';
