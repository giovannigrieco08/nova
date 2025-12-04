// Provider: TutorProviders
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Riverpod providers for tutor state management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/tutor_profile.dart';
import '../../domain/entities/subject.dart';
import '../../data/datasources/tutor_remote_datasource.dart';
import '../../data/repositories/tutor_repository.dart';

// ============================================================================
// DEPENDENCY INJECTION PROVIDERS
// ============================================================================

/// Supabase client provider (re-export for feature isolation)
final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Current user ID provider (from auth state)
final _currentUserIdProvider = Provider<String?>((ref) {
  final supabase = ref.watch(_supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});

/// Tutor remote datasource provider
final tutorDatasourceProvider = Provider<TutorRemoteDataSource>((ref) {
  final supabase = ref.watch(_supabaseClientProvider);
  return TutorRemoteDataSource(supabase);
});

/// Tutor repository provider
final tutorRepositoryProvider = Provider<TutorRepository>((ref) {
  final dataSource = ref.watch(tutorDatasourceProvider);
  return TutorRepository(dataSource);
});

// ============================================================================
// STATE PROVIDERS - Current User Tutor Profile
// ============================================================================

/// Current user's tutor profile provider
///
/// Returns null if user is not a tutor.
/// Use invalidate() to refresh after mutations.
///
/// Usage:
/// ```dart
/// final tutorAsync = ref.watch(currentTutorProfileProvider);
/// tutorAsync.when(
///   data: (tutor) => tutor == null ? BecomeTutorCard() : TutorProfileSection(),
///   loading: () => const SizedBox.shrink(),
///   error: (_, __) => const SizedBox.shrink(),
/// );
/// ```
final currentTutorProfileProvider = FutureProvider<TutorProfile?>((ref) async {
  final repository = ref.watch(tutorRepositoryProvider);
  final userId = ref.watch(_currentUserIdProvider);

  if (userId == null) return null;

  return await repository.getTutorProfile(userId);
});

/// Check if current user is a tutor
final isTutorProvider = FutureProvider<bool>((ref) async {
  final tutorProfile = await ref.watch(currentTutorProfileProvider.future);
  return tutorProfile != null;
});

// ============================================================================
// STATE PROVIDERS - Other User Tutor Profile
// ============================================================================

/// Other user's tutor profile provider (family)
///
/// Use for viewing another user's tutor profile on OtherProfileScreen.
/// Returns null if the user is not a tutor.
///
/// Usage:
/// ```dart
/// final tutorAsync = ref.watch(otherTutorProfileProvider(userId));
/// tutorAsync.when(
///   data: (tutor) => tutor == null
///       ? const SizedBox.shrink()
///       : TutorProfileSection(tutor: tutor, isOwnProfile: false),
///   loading: () => const SizedBox.shrink(),
///   error: (_, __) => const SizedBox.shrink(),
/// );
/// ```
final otherTutorProfileProvider =
    FutureProvider.family<TutorProfile?, String>((ref, userId) async {
  final repository = ref.watch(tutorRepositoryProvider);
  return await repository.getTutorProfile(userId);
});

// ============================================================================
// STATE PROVIDERS - Tutors List by Subject
// ============================================================================

/// Tutors by subject provider (family)
///
/// Fetches paginated list of active tutors for a given subject.
/// Sorted by rating (desc), then created_at (desc).
///
/// Usage:
/// ```dart
/// final tutorsAsync = ref.watch(tutorsBySubjectProvider(Subject.matematica));
/// tutorsAsync.when(
///   data: (tutors) => ListView.builder(
///     itemCount: tutors.length,
///     itemBuilder: (_, i) => TutorCard(tutor: tutors[i]),
///   ),
///   loading: () => const SkeletonLoading(),
///   error: (err, _) => ErrorWidget(error: err),
/// );
/// ```
final tutorsBySubjectProvider =
    FutureProvider.family<List<TutorProfileWithAuthorData>, Subject>(
        (ref, subject) async {
  final repository = ref.watch(tutorRepositoryProvider);
  return await repository.getTutorsBySubject(subject);
});

/// Filtered tutors provider (subject + price + class filter)
///
/// Usage:
/// ```dart
/// final tutorsAsync = ref.watch(filteredTutorsProvider(
///   TutorFilterParams(subject: Subject.matematica, priceFilter: 'free', classFilter: '3A'),
/// ));
/// ```
class TutorFilterParams {
  final Subject subject;
  final String? priceFilter;
  final String? classFilter;

  const TutorFilterParams({
    required this.subject,
    this.priceFilter,
    this.classFilter,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorFilterParams &&
          runtimeType == other.runtimeType &&
          subject == other.subject &&
          priceFilter == other.priceFilter &&
          classFilter == other.classFilter;

  @override
  int get hashCode => subject.hashCode ^ priceFilter.hashCode ^ classFilter.hashCode;
}

final filteredTutorsProvider =
    FutureProvider.family<List<TutorProfileWithAuthorData>, TutorFilterParams>(
        (ref, params) async {
  final repository = ref.watch(tutorRepositoryProvider);
  var tutors = await repository.getTutorsFiltered(
    params.subject,
    priceFilter: params.priceFilter,
  );

  // Client-side class filter (year prefix: 1, 2, 3, 4, 5)
  if (params.classFilter != null && params.classFilter!.isNotEmpty) {
    tutors = tutors.where((t) {
      final tutorClass = t.authorClass;
      if (tutorClass == null || tutorClass.isEmpty) return false;
      return tutorClass.startsWith(params.classFilter!);
    }).toList();
  }

  return tutors;
});

// ============================================================================
// MUTATION PROVIDERS
// ============================================================================

/// Create tutor profile mutation result
class CreateTutorResult {
  final TutorProfile? profile;
  final String? error;

  const CreateTutorResult({this.profile, this.error});

  bool get isSuccess => profile != null && error == null;
}

/// Create tutor profile provider
///
/// Usage:
/// ```dart
/// final notifier = ref.read(createTutorProfileProvider.notifier);
/// final result = await notifier.create(
///   bio: 'Amo la matematica!',
///   subjects: [Subject.matematica, Subject.fisica],
///   pricePerHour: 15.0,
///   whatsappPhone: '393201234567',
/// );
///
/// if (result.isSuccess) {
///   showSnackbar('Profilo tutor creato!');
///   ref.invalidate(currentTutorProfileProvider);
/// } else {
///   showSnackbar(result.error!);
/// }
/// ```
class CreateTutorProfileNotifier extends StateNotifier<AsyncValue<CreateTutorResult?>> {
  final TutorRepository _repository;
  final Ref _ref;

  CreateTutorProfileNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<CreateTutorResult> create({
    String? bio,
    required List<Subject> subjects,
    double pricePerHour = 0.0,
    List<AvailabilityDay> availabilityDays = const [],
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
  }) async {
    state = const AsyncValue.loading();

    try {
      final userId = _ref.read(_currentUserIdProvider);
      if (userId == null) {
        const result = CreateTutorResult(error: 'Utente non autenticato');
        state = const AsyncValue.data(result);
        return result;
      }

      final profile = await _repository.createTutorProfile(
        userId: userId,
        bio: bio,
        subjects: subjects,
        pricePerHour: pricePerHour,
        availabilityDays: availabilityDays,
        timeSlot: timeSlot,
        whatsappPhone: whatsappPhone,
        instagramUsername: instagramUsername,
      );

      // Invalidate current tutor profile to refresh
      _ref.invalidate(currentTutorProfileProvider);

      final result = CreateTutorResult(profile: profile);
      state = AsyncValue.data(result);
      return result;
    } on TutorAlreadyExistsException catch (e) {
      final result = CreateTutorResult(error: e.message);
      state = AsyncValue.data(result);
      return result;
    } on TutorValidationException catch (e) {
      final result = CreateTutorResult(error: e.message);
      state = AsyncValue.data(result);
      return result;
    } catch (e, stack) {
      final result = CreateTutorResult(error: 'Errore: ${e.toString()}');
      state = AsyncValue.error(e, stack);
      return result;
    }
  }
}

final createTutorProfileProvider =
    StateNotifierProvider<CreateTutorProfileNotifier, AsyncValue<CreateTutorResult?>>((ref) {
  final repository = ref.watch(tutorRepositoryProvider);
  return CreateTutorProfileNotifier(repository, ref);
});

/// Update tutor profile mutation result
class UpdateTutorResult {
  final TutorProfile? profile;
  final String? error;

  const UpdateTutorResult({this.profile, this.error});

  bool get isSuccess => profile != null && error == null;
}

/// Update tutor profile provider
class UpdateTutorProfileNotifier extends StateNotifier<AsyncValue<UpdateTutorResult?>> {
  final TutorRepository _repository;
  final Ref _ref;

  UpdateTutorProfileNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<UpdateTutorResult> update({
    String? bio,
    List<Subject>? subjects,
    double? pricePerHour,
    List<AvailabilityDay>? availabilityDays,
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
  }) async {
    state = const AsyncValue.loading();

    try {
      final userId = _ref.read(_currentUserIdProvider);
      if (userId == null) {
        const result = UpdateTutorResult(error: 'Utente non autenticato');
        state = const AsyncValue.data(result);
        return result;
      }

      final profile = await _repository.updateTutorProfile(
        userId,
        bio: bio,
        subjects: subjects,
        pricePerHour: pricePerHour,
        availabilityDays: availabilityDays,
        timeSlot: timeSlot,
        whatsappPhone: whatsappPhone,
        instagramUsername: instagramUsername,
      );

      // Invalidate current tutor profile to refresh
      _ref.invalidate(currentTutorProfileProvider);

      final result = UpdateTutorResult(profile: profile);
      state = AsyncValue.data(result);
      return result;
    } on TutorValidationException catch (e) {
      final result = UpdateTutorResult(error: e.message);
      state = AsyncValue.data(result);
      return result;
    } catch (e, stack) {
      final result = UpdateTutorResult(error: 'Errore: ${e.toString()}');
      state = AsyncValue.error(e, stack);
      return result;
    }
  }
}

final updateTutorProfileProvider =
    StateNotifierProvider<UpdateTutorProfileNotifier, AsyncValue<UpdateTutorResult?>>((ref) {
  final repository = ref.watch(tutorRepositoryProvider);
  return UpdateTutorProfileNotifier(repository, ref);
});

/// Toggle tutor active provider
class ToggleTutorActiveNotifier extends StateNotifier<AsyncValue<TutorProfile?>> {
  final TutorRepository _repository;
  final Ref _ref;

  ToggleTutorActiveNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<TutorProfile?> toggle(bool isActive) async {
    state = const AsyncValue.loading();

    try {
      final userId = _ref.read(_currentUserIdProvider);
      if (userId == null) {
        state = const AsyncValue.data(null);
        return null;
      }

      final profile = await _repository.toggleTutorActive(userId, isActive);

      // Invalidate current tutor profile to refresh
      _ref.invalidate(currentTutorProfileProvider);

      state = AsyncValue.data(profile);
      return profile;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<TutorProfile?> deactivate() => toggle(false);
  Future<TutorProfile?> reactivate() => toggle(true);
}

final toggleTutorActiveProvider =
    StateNotifierProvider<ToggleTutorActiveNotifier, AsyncValue<TutorProfile?>>((ref) {
  final repository = ref.watch(tutorRepositoryProvider);
  return ToggleTutorActiveNotifier(repository, ref);
});
