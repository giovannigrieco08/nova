/// Tutoring feature module - Sistema Ripetizioni
///
/// Provides peer-to-peer tutoring functionality for students at Liceo Galilei Moro.
/// Students can offer and find tutoring services by subject with contact via
/// WhatsApp or Instagram.
///
/// Feature: 012-tutoring-system
/// Branch: 012-tutoring-system

// Domain - Entities
export 'domain/entities/subject.dart';
export 'domain/entities/tutor_profile.dart';

// Data - Models
export 'data/models/tutor_profile_model.dart';

// Data - Datasources
export 'data/datasources/tutor_remote_datasource.dart';

// Data - Repositories
export 'data/repositories/tutor_repository.dart';

// Presentation - Providers
export 'presentation/providers/tutor_providers.dart';

// Presentation - Screens
export 'presentation/screens/subjects_screen.dart';
export 'presentation/screens/tutors_list_screen.dart';
export 'presentation/screens/become_tutor_screen.dart';
export 'presentation/screens/edit_tutor_screen.dart';

// Presentation - Widgets
export 'presentation/widgets/subject_card.dart';
export 'presentation/widgets/tutor_card.dart';
export 'presentation/widgets/contact_tutor_sheet.dart';
export 'presentation/widgets/tutor_profile_section.dart';
export 'presentation/widgets/become_tutor_card.dart';
