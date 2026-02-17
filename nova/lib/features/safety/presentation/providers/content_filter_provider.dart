import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_check_result.dart';
import '../../data/repositories/content_filter_repository.dart';
import '../../domain/services/content_filter_service.dart';

/// Provider for ContentFilterRepository
final contentFilterRepositoryProvider =
    Provider<ContentFilterRepository>((ref) {
  return ContentFilterRepository();
});

/// Provider for ContentFilterService
final contentFilterServiceProvider = Provider<ContentFilterService>((ref) {
  return ContentFilterService(
    repository: ref.watch(contentFilterRepositoryProvider),
  );
});

/// State for content check
class ContentCheckState {
  const ContentCheckState({
    this.isChecking = false,
    this.result,
    this.lastCheckedText,
  });

  final bool isChecking;
  final ContentCheckResult? result;
  final String? lastCheckedText;

  bool get isBlocked => result?.blocked ?? false;
  bool get hasWarnings => result?.hasWarnings ?? false;
  bool get isClean => result?.isClean ?? true;

  ContentCheckState copyWith({
    bool? isChecking,
    ContentCheckResult? result,
    String? lastCheckedText,
  }) {
    return ContentCheckState(
      isChecking: isChecking ?? this.isChecking,
      result: result ?? this.result,
      lastCheckedText: lastCheckedText ?? this.lastCheckedText,
    );
  }
}

/// Notifier for content checking with debounce
class ContentCheckNotifier extends StateNotifier<ContentCheckState> {
  ContentCheckNotifier(this._service) : super(const ContentCheckState());

  final ContentFilterService _service;
  Timer? _debounceTimer;

  /// Check content with debounce (for real-time validation)
  void checkWithDebounce(String text,
      {Duration delay = const Duration(milliseconds: 500)}) {
    _debounceTimer?.cancel();

    if (text.trim().length < 3) {
      state = const ContentCheckState();
      return;
    }

    state = state.copyWith(isChecking: true);

    _debounceTimer = Timer(delay, () async {
      await _checkContent(text);
    });
  }

  /// Check content immediately (for submission)
  Future<ContentCheckResult> checkNow(String text) async {
    _debounceTimer?.cancel();
    return _checkContent(text);
  }

  Future<ContentCheckResult> _checkContent(String text) async {
    state = state.copyWith(isChecking: true);

    try {
      final result = await _service.checkContent(text);
      state = ContentCheckState(
        isChecking: false,
        result: result,
        lastCheckedText: text,
      );
      return result;
    } catch (e) {
      state = state.copyWith(isChecking: false);
      return ContentCheckResult.clean();
    }
  }

  /// Reset state
  void reset() {
    _debounceTimer?.cancel();
    state = const ContentCheckState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for content check state
final contentCheckNotifierProvider =
    StateNotifierProvider.autoDispose<ContentCheckNotifier, ContentCheckState>(
        (ref) {
  return ContentCheckNotifier(ref.watch(contentFilterServiceProvider));
});

/// Provider for single content check
final contentCheckProvider = FutureProvider.family<ContentCheckResult, String>(
  (ref, text) async {
    final service = ref.watch(contentFilterServiceProvider);
    return service.checkContent(text);
  },
);

/// Provider for banned words list (moderators)
final bannedWordsProvider = FutureProvider<List<BannedWord>>((ref) async {
  final repository = ref.watch(contentFilterRepositoryProvider);
  return repository.getBannedWords();
});
