# Phase 4: Admin Panel Implementation Guide

**Feature**: 005-moderation-admin-panel
**User Story**: 2 - Moderator Management by Admin (P2)
**Tasks**: T052-T068 (17 tasks)
**Status**: Ready for implementation (database and foundation complete)

---

## Prerequisites ✅

Before starting Phase 4, verify these are complete:

- [x] Phase 1: Database migration deployed (T001-T023)
- [x] Phase 2: Flutter foundation ready (T024-T033)
- [x] Phase 3: MVP moderation queue working (T034-T051)
- [x] Database functions exist: `promote_to_moderator()`, `remove_moderator_role()`, `get_system_statistics()`
- [x] `userRoleProvider` exists and streams role changes
- [x] `NovaBottomNavBar` supports role-based tab visibility

---

## Architecture Overview

```
nova/lib/features/admin/
├── data/
│   ├── models/
│   │   └── admin_action.dart           # T052 - Freezed model for admin_log table
│   └── repositories/
│       └── admin_repository.dart       # T055 - RPC calls to database functions
├── domain/
│   └── entities/
│       ├── moderator.dart              # T053 - User + stats entity
│       └── system_stats.dart           # T054 - System-wide metrics
└── presentation/
    ├── providers/
    │   ├── moderators_provider.dart         # T056 - Realtime moderator list
    │   ├── system_stats_provider.dart       # T057 - System stats stream
    │   └── admin_actions_notifier.dart      # T058 - Promote/remove actions
    ├── widgets/
    │   ├── moderator_search.dart       # T059 - Debounced search (500ms)
    │   ├── moderator_card.dart         # T060 - Moderator info + remove button
    │   └── system_statistics_widget.dart  # T061 - Stats with backlog highlighting
    └── screens/
        └── admin_panel_screen.dart     # T062 - Main admin screen (3 sections)
```

---

## Implementation Steps

### Step 1: Data Layer (T052-T055)

#### T052: AdminAction Model

**File**: `nova/lib/features/admin/data/models/admin_action.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_action.freezed.dart';
part 'admin_action.g.dart';

@freezed
class AdminAction with _$AdminAction {
  const factory AdminAction({
    required String id,
    required String adminId,
    required String targetUserId,
    required String action, // 'promoted' | 'removed'
    String? oldRole,
    required String newRole,
    required DateTime createdAt,
  }) = _AdminAction;

  factory AdminAction.fromJson(Map<String, dynamic> json) =>
      _$AdminActionFromJson(json);
}
```

#### T053: Moderator Entity

**File**: `nova/lib/features/admin/domain/entities/moderator.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'moderator.freezed.dart';
part 'moderator.g.dart';

@freezed
class Moderator with _$Moderator {
  const factory Moderator({
    required String userId,
    required String fullName,
    required String email,
    required String className,
    @Default(0) int totalReviews,
    @Default(0) int reviewsThisWeek,
    @Default(0.0) double approvalRatePercent,
    DateTime? lastReviewAt,
  }) = _Moderator;

  factory Moderator.fromJson(Map<String, dynamic> json) =>
      _$ModeratorFromJson(json);
}

extension ModeratorX on Moderator {
  bool get isActive {
    if (lastReviewAt == null) return false;
    return DateTime.now().difference(lastReviewAt!).inDays <= 7;
  }

  String get lastActivityText {
    if (lastReviewAt == null) return 'Mai';
    final diff = DateTime.now().difference(lastReviewAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m fa';
    if (diff.inHours < 24) return '${diff.inHours}h fa';
    if (diff.inDays < 7) return '${diff.inDays}g fa';
    return '${(diff.inDays / 7).floor()}w fa';
  }
}
```

#### T054: SystemStats Entity

**File**: `nova/lib/features/admin/domain/entities/system_stats.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_stats.freezed.dart';
part 'system_stats.g.dart';

@freezed
class SystemStats with _$SystemStats {
  const factory SystemStats({
    @Default(0) int totalEvents,
    @Default(0) int pendingEvents,
    @Default(0) int approvedEvents,
    @Default(0) int rejectedEvents,
    @Default(0) int totalModerators,
    @Default(0) int activeModerators,
    @Default(0.0) double avgReviewTimeHours,
    @Default(0) int eventsOlderThan24h, // Backlog - highlight red if >0
  }) = _SystemStats;

  factory SystemStats.fromJson(Map<String, dynamic> json) =>
      _$SystemStatsFromJson(json);
}

extension SystemStatsX on SystemStats {
  double get approvalRatePercent {
    final reviewed = approvedEvents + rejectedEvents;
    if (reviewed == 0) return 0.0;
    return (approvedEvents / reviewed) * 100;
  }

  bool get hasBacklogCrisis => eventsOlderThan24h > 10;
}
```

#### T055: AdminRepository

**File**: `nova/lib/features/admin/data/repositories/admin_repository.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  /// Search users by name, email, or class
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final response = await _supabase
        .from('profiles')
        .select('id, full_name, email, class_name')
        .or('full_name.ilike.%$query%,email.ilike.%$query%,class_name.ilike.%$query%')
        .order('full_name')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Promote user to moderator (calls database function)
  Future<void> promoteToModerator(String userId) async {
    await _supabase.rpc('promote_to_moderator', params: {
      'p_user_id': userId,
    });
  }

  /// Remove moderator role (calls database function)
  Future<void> removeModerator(String userId) async {
    await _supabase.rpc('remove_moderator_role', params: {
      'p_user_id': userId,
    });
  }

  /// Get all moderators with statistics
  Future<List<Moderator>> getModerators() async {
    final response = await _supabase
        .from('user_roles')
        .select('''
          user_id,
          profiles!inner(full_name, email, class_name),
          moderator_stats(total_reviews, reviews_this_week, approval_rate_percent, last_review_at)
        ''')
        .eq('role', 'moderator')
        .order('profiles.full_name');

    return (response as List).map((json) {
      return Moderator(
        userId: json['user_id'],
        fullName: json['profiles']['full_name'],
        email: json['profiles']['email'],
        className: json['profiles']['class_name'],
        totalReviews: json['moderator_stats']?['total_reviews'] ?? 0,
        reviewsThisWeek: json['moderator_stats']?['reviews_this_week'] ?? 0,
        approvalRatePercent:
            (json['moderator_stats']?['approval_rate_percent'] ?? 0.0).toDouble(),
        lastReviewAt: json['moderator_stats']?['last_review_at'] != null
            ? DateTime.parse(json['moderator_stats']['last_review_at'])
            : null,
      );
    }).toList();
  }

  /// Get system statistics (calls database function)
  Future<SystemStats> getSystemStats() async {
    final response = await _supabase.rpc('get_system_statistics');
    return SystemStats.fromJson(response);
  }
}

// Provider
@riverpod
AdminRepository adminRepository(AdminRepositoryRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminRepository(supabase);
}
```

**After creating T052-T054, run**:
```bash
cd nova
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 2: Presentation Layer (T056-T058)

#### T056: Moderators Provider

**File**: `nova/lib/features/admin/presentation/providers/moderators_provider.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';

part 'moderators_provider.g.dart';

/// Provider for all moderators with real-time updates
@riverpod
Stream<List<Moderator>> moderators(ModeratorsRef ref) async* {
  final repository = ref.watch(adminRepositoryProvider);

  // Initial fetch
  yield await repository.getModerators();

  // Subscribe to user_roles changes for real-time updates
  final supabase = ref.watch(supabaseClientProvider);
  await for (final _ in supabase
      .from('user_roles')
      .stream(primaryKey: ['id'])
      .eq('role', 'moderator')) {
    yield await repository.getModerators();
  }
}
```

#### T057: System Stats Provider

**File**: `nova/lib/features/admin/presentation/providers/system_stats_provider.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';

part 'system_stats_provider.g.dart';

/// Provider for system-wide statistics with periodic refresh
@riverpod
Stream<SystemStats> systemStats(SystemStatsRef ref) async* {
  final repository = ref.watch(adminRepositoryProvider);

  // Refresh every 30 seconds
  while (true) {
    yield await repository.getSystemStats();
    await Future.delayed(Duration(seconds: 30));
  }
}
```

#### T058: Admin Actions Notifier

**File**: `nova/lib/features/admin/presentation/providers/admin_actions_notifier.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';

part 'admin_actions_notifier.g.dart';

@riverpod
class AdminActionsNotifier extends _$AdminActionsNotifier {
  @override
  FutureOr<void> build() => null;

  /// Promote user to moderator
  Future<void> promoteUser(String userId) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(adminRepositoryProvider);
      await repository.promoteToModerator(userId);

      // Invalidate moderators list to refresh
      ref.invalidate(moderatorsProvider);

      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Remove moderator role
  Future<void> removeUser(String userId) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(adminRepositoryProvider);
      await repository.removeModerator(userId);

      // Invalidate moderators list to refresh
      ref.invalidate(moderatorsProvider);

      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
```

**After creating T056-T058, run**:
```bash
cd nova
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 3: UI Components (T059-T062)

#### T059: Moderator Search Widget (Debounced)

**File**: `nova/lib/features/admin/presentation/widgets/moderator_search.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_text_field.dart';
import 'package:nova/features/admin/data/repositories/admin_repository.dart';

/// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search results
final searchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final repository = ref.watch(adminRepositoryProvider);
  return repository.searchUsers(query);
});

class ModeratorSearch extends ConsumerStatefulWidget {
  const ModeratorSearch({super.key});

  @override
  ConsumerState<ModeratorSearch> createState() => _ModeratorSearchState();
}

class _ModeratorSearchState extends ConsumerState<ModeratorSearch> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveTextField(
          controller: _searchController,
          placeholder: 'Cerca per nome, email o classe...',
          prefixIcon: Icon(Icons.search),
          clearButtonMode: OverlayVisibilityMode.editing,
        ),
        SizedBox(height: NovaSpacing.m),
        searchResults.when(
          data: (users) {
            if (users.isEmpty && _searchController.text.isNotEmpty) {
              return Text('Nessun risultato');
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user['full_name']),
                  subtitle: Text('${user['email']} • ${user['class_name']}'),
                  trailing: AdaptiveButton(
                    type: AdaptiveButtonType.primary,
                    onPressed: () => _showPromotionDialog(context, ref, user),
                    child: Text('Promuovi'),
                  ),
                );
              },
            );
          },
          loading: () => CircularProgressIndicator(),
          error: (err, _) => Text('Errore: $err'),
        ),
      ],
    );
  }

  Future<void> _showPromotionDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
  ) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AdaptiveDialog(
        title: 'Promuovi a moderatore',
        content: Text(
          '${user['full_name']} (${user['class_name']}) diventerà moderatore '
          'e potrà approvare/rifiutare eventi.',
        ),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annulla'),
          ),
          AdaptiveDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('Promuovi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(adminActionsNotifierProvider.notifier)
          .promoteUser(user['id']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['full_name']} promosso a moderatore!')),
        );
      }

      _searchController.clear();
    }
  }
}
```

#### T060: Moderator Card Widget

**File**: `nova/lib/features/admin/presentation/widgets/moderator_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_text_styles.dart';
import 'package:nova/features/admin/domain/entities/moderator.dart';
import 'package:nova/features/admin/presentation/providers/admin_actions_notifier.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_button.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_dialog.dart';

class ModeratorCard extends ConsumerWidget {
  final Moderator moderator;

  const ModeratorCard({required this.moderator, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(NovaRadius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moderator.fullName,
                      style: NovaTextStyles.bodyLarge,
                    ),
                    Text(
                      '${moderator.email} • ${moderator.className}',
                      style: NovaTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.s,
                  vertical: NovaSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: moderator.isActive
                      ? NovaColors.success.withOpacity(0.2)
                      : NovaColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(NovaRadius.s),
                ),
                child: Text(
                  moderator.isActive ? 'Attivo' : 'Inattivo',
                  style: NovaTextStyles.bodySmall.copyWith(
                    color: moderator.isActive ? NovaColors.success : NovaColors.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: NovaSpacing.m),
          Row(
            children: [
              _statBox('Totale', '${moderator.totalReviews}'),
              SizedBox(width: NovaSpacing.s),
              _statBox('Settimana', '${moderator.reviewsThisWeek}'),
              SizedBox(width: NovaSpacing.s),
              _statBox('Approval', '${moderator.approvalRatePercent.toStringAsFixed(0)}%'),
              SizedBox(width: NovaSpacing.s),
              _statBox('Ultima', moderator.lastActivityText),
            ],
          ),
          SizedBox(height: NovaSpacing.m),
          AdaptiveButton(
            type: AdaptiveButtonType.destructive,
            onPressed: () => _showRemovalDialog(context, ref),
            child: Text('Rimuovi Ruolo'),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(NovaRadius.s),
        ),
        child: Column(
          children: [
            Text(value, style: NovaTextStyles.bodyMedium),
            Text(label, style: NovaTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemovalDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AdaptiveDialog(
        title: 'Rimuovi ruolo moderatore',
        content: Text(
          '${moderator.fullName} perderà accesso alla dashboard moderazione. '
          'Le statistiche saranno archiviate.',
        ),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annulla'),
          ),
          AdaptiveDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(adminActionsNotifierProvider.notifier)
          .removeUser(moderator.userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ruolo moderatore rimosso')),
        );
      }
    }
  }
}
```

#### T061: System Statistics Widget

**File**: `nova/lib/features/admin/presentation/widgets/system_statistics_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_text_styles.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';

class SystemStatisticsWidget extends StatelessWidget {
  final SystemStats stats;

  const SystemStatisticsWidget({required this.stats, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Events row
        Row(
          children: [
            _statCard('Totale', '${stats.totalEvents}', NovaColors.info),
            SizedBox(width: NovaSpacing.m),
            _statCard('Pending', '${stats.pendingEvents}', NovaColors.warning),
            SizedBox(width: NovaSpacing.m),
            _statCard('Approvati', '${stats.approvedEvents}', NovaColors.success),
            SizedBox(width: NovaSpacing.m),
            _statCard('Rifiutati', '${stats.rejectedEvents}', NovaColors.error),
          ],
        ),
        SizedBox(height: NovaSpacing.m),
        // Moderators row
        Row(
          children: [
            _statCard('Moderatori', '${stats.totalModerators}', NovaColors.info),
            SizedBox(width: NovaSpacing.m),
            _statCard('Attivi', '${stats.activeModerators}', NovaColors.success),
            SizedBox(width: NovaSpacing.m),
            _statCard(
              'Backlog >24h',
              '${stats.eventsOlderThan24h}',
              stats.eventsOlderThan24h > 0 ? NovaColors.error : NovaColors.success,
              highlight: stats.eventsOlderThan24h > 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(NovaSpacing.m),
        decoration: BoxDecoration(
          color: highlight ? color.withOpacity(0.2) : NovaColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(NovaRadius.m),
          border: highlight ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: NovaTextStyles.headingLarge.copyWith(
                color: highlight ? color : NovaColors.textPrimary,
              ),
            ),
            SizedBox(height: NovaSpacing.xs),
            Text(label, style: NovaTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
```

#### T062: Admin Panel Screen

**File**: `nova/lib/features/admin/presentation/screens/admin_panel_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_text_styles.dart';
import 'package:nova/features/admin/presentation/providers/moderators_provider.dart';
import 'package:nova/features/admin/presentation/providers/system_stats_provider.dart';
import 'package:nova/features/admin/presentation/widgets/moderator_search.dart';
import 'package:nova/features/admin/presentation/widgets/moderator_card.dart';
import 'package:nova/features/admin/presentation/widgets/system_statistics_widget.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_scaffold.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_app_bar.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moderatorsAsync = ref.watch(moderatorsProvider);
    final systemStatsAsync = ref.watch(systemStatsProvider);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Admin Panel'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Search
            Text('Cerca studente', style: NovaTextStyles.headingMedium),
            SizedBox(height: NovaSpacing.m),
            ModeratorSearch(),

            SizedBox(height: NovaSpacing.xl),

            // Section 2: Moderators list
            Text('Moderatori attuali', style: NovaTextStyles.headingMedium),
            SizedBox(height: NovaSpacing.m),
            moderatorsAsync.when(
              data: (moderators) {
                if (moderators.isEmpty) {
                  return Text('Nessun moderatore');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: moderators.length,
                  separatorBuilder: (_, __) => SizedBox(height: NovaSpacing.m),
                  itemBuilder: (_, index) => ModeratorCard(moderator: moderators[index]),
                );
              },
              loading: () => CircularProgressIndicator(),
              error: (err, _) => Text('Errore: $err'),
            ),

            SizedBox(height: NovaSpacing.xl),

            // Section 3: System statistics
            Text('Statistiche sistema', style: NovaTextStyles.headingMedium),
            SizedBox(height: NovaSpacing.m),
            systemStatsAsync.when(
              data: (stats) => SystemStatisticsWidget(stats: stats),
              loading: () => CircularProgressIndicator(),
              error: (err, _) => Text('Errore: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 4: Role Change Listener (T065)

**File**: Update `main.dart` or app root widget

```dart
// In your app root (MaterialApp or similar)
class NovaApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            RoleChangeListener(), // Add this
          ],
        );
      },
    );
  }
}

// Create this widget
class RoleChangeListener extends ConsumerWidget {
  const RoleChangeListener({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(userRoleProvider, (previous, next) {
      final prevRole = previous?.valueOrNull;
      final newRole = next.valueOrNull;

      if (prevRole != newRole && newRole != null) {
        if (newRole == UserRole.moderator && prevRole == UserRole.student) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sei stato promosso a moderatore!'),
              backgroundColor: NovaColors.success,
              action: SnackBarAction(
                label: 'Vai',
                onPressed: () => context.go('/moderation'),
              ),
            ),
          );
        } else if (newRole == UserRole.student && prevRole == UserRole.moderator) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Il tuo ruolo di moderatore è stato rimosso.'),
              backgroundColor: NovaColors.warning,
            ),
          );

          // Navigate away from /moderation if currently there
          final currentRoute = GoRouterState.of(context).matchedLocation;
          if (currentRoute.startsWith('/moderation')) {
            context.go('/events');
          }
        }
      }
    });

    return const SizedBox.shrink();
  }
}
```

---

### Step 5: Integration (T066-T068)

#### T066: Add "Admin" Tab to Bottom Nav

Update `NovaBottomNavBar` or navigation configuration:

```dart
final navigationItems = [
  NavigationItem(
    route: '/events',
    icon: Icons.event,
    label: 'Eventi',
    allowedRoles: [UserRole.student, UserRole.moderator, UserRole.admin],
  ),
  NavigationItem(
    route: '/moderation',
    icon: Icons.gavel,
    label: 'Moderazione',
    allowedRoles: [UserRole.moderator, UserRole.admin],
  ),
  NavigationItem(
    route: '/admin',
    icon: Icons.admin_panel_settings,
    label: 'Admin',
    allowedRoles: [UserRole.admin], // Only admin
  ),
  NavigationItem(
    route: '/profile',
    icon: Icons.person,
    label: 'Profilo',
    allowedRoles: [UserRole.student, UserRole.moderator, UserRole.admin],
  ),
];
```

#### T067: Add Role Guard on /admin Route

Update `AppRouter`:

```dart
GoRoute(
  path: '/admin',
  redirect: (context, state) {
    final role = ref.read(userRoleProvider).valueOrNull;
    if (role != UserRole.admin) {
      return '/events'; // Redirect non-admins
    }
    return null;
  },
  builder: (context, state) => AdminPanelScreen(),
)
```

#### T068: Verify Notification Trigger

The database function `promote_to_moderator()` already creates notification records:

```sql
-- In promote_to_moderator() function
INSERT INTO notifications (recipient_id, title, body, data)
VALUES (
  p_user_id,
  'Promosso a moderatore',
  'Ora puoi approvare/rifiutare eventi dalla dashboard moderazione.',
  jsonb_build_object(
    'type', 'role_change',
    'new_role', 'moderator'
  )
);
```

Verify this works by:
1. Promoting a user
2. Checking `notifications` table for new record
3. Verifying push notification webhook triggers (if configured)

---

## Testing Checklist

After implementation, test these scenarios:

### Admin Can Promote Students
- [ ] Search for student by name
- [ ] Search for student by email
- [ ] Search for student by class
- [ ] Promote button shows confirmation dialog
- [ ] After promotion, user appears in moderators list
- [ ] Promoted user receives notification
- [ ] Promoted user sees "Moderazione" tab

### Admin Can Remove Moderators
- [ ] All moderators show in list with stats
- [ ] Remove button shows confirmation dialog
- [ ] After removal, user disappears from moderators list
- [ ] Removed user loses access to "Moderazione" tab
- [ ] Statistics are archived (check moderator_stats_archive)

### Role Change Real-Time Updates
- [ ] User gets SnackBar when promoted (while app is open)
- [ ] User gets SnackBar when demoted (while app is open)
- [ ] If demoted while on /moderation, navigates to /events
- [ ] Navigation tabs update immediately on role change

### System Statistics
- [ ] All event counts display correctly
- [ ] Moderator counts display correctly
- [ ] Backlog >24h highlighted red if >0
- [ ] Stats refresh every 30 seconds

### Access Control
- [ ] Students cannot access /admin (redirected to /events)
- [ ] Moderators cannot access /admin (redirected to /events)
- [ ] Only admins see "Admin" tab in bottom nav
- [ ] Only admins can promote/remove moderators

---

## Build Commands

After creating all files:

```bash
cd nova

# Generate Freezed code
dart run build_runner build --delete-conflicting-outputs

# Verify no errors
flutter analyze

# Run app
flutter run
```

---

## Next Steps After Phase 4

Once Phase 4 is complete (T052-T068 all done), you will have:

✅ **50 tasks complete** (Phase 1-3)
✅ **17 tasks complete** (Phase 4) = **67/125 tasks (53.6%)**

**Remaining phases:**
- Phase 5: Real-time Statistics (8 tasks) - P2
- Phase 6: Admin Activity Log (9 tasks) - P3
- Phase 7: Event Re-submission (12 tasks) - P3
- Phase 8: Push Notifications (12 tasks)
- Phase 9: Polish & Cross-Cutting (16 tasks)

Total remaining: **58 tasks**

---

## Constitutional Compliance Verification

Before marking Phase 4 complete, verify:

- [ ] **STUDENTS_FIRST**: Moderators are students (not teachers/admins)
- [ ] **PRIVACY_FOUNDATION**: Admin cannot see PII beyond necessary info
- [ ] **SIMPLICITY_FIRST**: UI is minimal, focused on core tasks
- [ ] **PERFORMANCE_FIRST**: <1s dashboard load, 60fps rendering
- [ ] **SPEC_FIRST**: All tasks match spec.md requirements
- [ ] **DESIGN_SYSTEM_STRICT**: Zero hardcoded values (all from NovaColors, NovaSpacing, NovaTextStyles, NovaRadius)
- [ ] **CONTENT_MODERATION**: Moderator management enforces accountability

---

**Status**: Ready for implementation
**Estimated Time**: 3-4 hours for experienced Flutter developer
**Complexity**: Medium (Freezed models, Riverpod providers, RPC calls, real-time subscriptions)
