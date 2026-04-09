/// Safety feature module for UGC compliance (Apple Guideline 1.2)
///
/// This module provides:
/// - Report system for flagging inappropriate content
/// - User blocking functionality
/// - Terms of Service acceptance tracking
/// - Content filtering for banned words
/// - Moderation tools for administrators
library safety;

// Models
export 'data/models/report.dart';
export 'data/models/user_block.dart';
export 'data/models/tos_status.dart';
export 'data/models/content_check_result.dart';
export 'data/models/user_sanction.dart';

// Repositories
export 'data/repositories/report_repository.dart';
export 'data/repositories/block_repository.dart';
export 'data/repositories/tos_repository.dart';
export 'data/repositories/content_filter_repository.dart';

// Data - Providers
export 'data/providers/safety_data_providers.dart';

// Services
export 'domain/services/report_service.dart';
export 'domain/services/block_service.dart';
export 'domain/services/tos_service.dart';
export 'domain/services/content_filter_service.dart';

// Providers
export 'presentation/providers/report_provider.dart';
export 'presentation/providers/block_provider.dart';
export 'presentation/providers/tos_provider.dart';
export 'presentation/providers/content_filter_provider.dart';

// Screens
export 'presentation/screens/tos_acceptance_screen.dart';
export 'presentation/screens/blocked_users_screen.dart';

// Widgets
export 'presentation/widgets/report_button.dart';
export 'presentation/widgets/report_sheet.dart';
export 'presentation/widgets/block_button.dart';
export 'presentation/widgets/content_warning_banner.dart';
