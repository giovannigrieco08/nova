/// Global Chat Feature - 011-global-chat
///
/// Real-time school-wide chat system with:
/// - Ephemeral messaging (24-hour auto-delete)
/// - @mentions with notifications
/// - Emoji reactions
/// - Reply threading
/// - Typing indicators
/// - View-once media with screenshot protection
///
/// Entry point: [ChatScreen]
library chat;

// Domain - Entities
export 'domain/entities/chat_message.dart';
export 'domain/entities/mention_info.dart';
export 'domain/entities/chat_reaction.dart';
export 'domain/entities/chat_report.dart';
export 'domain/entities/chat_media_info.dart';

// Domain - Repositories
export 'domain/repositories/chat_repository.dart';

// Data - Models
export 'data/models/chat_message_model.dart';
export 'data/models/chat_reaction_model.dart';
export 'data/models/chat_report_model.dart';
export 'data/models/chat_media_model.dart';

// Data - Datasources
export 'data/datasources/chat_remote_datasource.dart';

// Data - Repositories
export 'data/repositories/chat_repository_impl.dart';

// Presentation - Providers
export 'presentation/providers/chat_providers.dart';
export 'presentation/providers/chat_realtime_provider.dart';
export 'presentation/providers/typing_indicator_provider.dart';

// Presentation - Screens
export 'presentation/screens/chat_screen.dart';
export 'presentation/screens/media_viewer_screen.dart';

// Presentation - Widgets
export 'presentation/widgets/chat_message_list.dart';
export 'presentation/widgets/chat_message_tile.dart';
export 'presentation/widgets/chat_compose_bar.dart';
export 'presentation/widgets/chat_reply_preview.dart';
export 'presentation/widgets/chat_reaction_row.dart';
export 'presentation/widgets/chat_typing_indicator.dart';
export 'presentation/widgets/chat_report_dialog.dart';
// P2/P3 widgets (to be implemented):
// export 'presentation/widgets/chat_reaction_picker.dart';
// export 'presentation/widgets/mention_autocomplete.dart';
// export 'presentation/widgets/view_once_badge.dart';
