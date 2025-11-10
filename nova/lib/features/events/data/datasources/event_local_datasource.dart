// Data Source: EventLocalDataSource
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Hive local storage for event drafts with debounced auto-save
//
// Draft auto-save strategy:
// - Debounced save every 500ms during form input (prevents excessive writes)
// - Single draft per user (overwrites previous draft)
// - Deleted on successful event creation

import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event_draft.dart';

/// Local data source for event draft persistence via Hive
class EventLocalDataSource {
  final Box<EventDraft> _draftsBox;

  /// Debounce timer for auto-save (500ms)
  Timer? _debounceTimer;

  /// Debounce duration (500ms)
  static const _debounceDuration = Duration(milliseconds: 500);

  EventLocalDataSource(this._draftsBox);

  // =========================================================================
  // DRAFT OPERATIONS
  // =========================================================================

  /// Save draft with debouncing (auto-save every 500ms)
  ///
  /// Cancels previous timer and starts new one to prevent excessive writes.
  /// Useful for real-time form input auto-save.
  ///
  /// Example usage in EventFormState:
  /// ```dart
  /// void updateTitle(String title) {
  ///   state = state.copyWith(title: title);
  ///   _localDataSource.saveDraftDebounced(_createDraft());
  /// }
  /// ```
  void saveDraftDebounced(EventDraft draft) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer
    _debounceTimer = Timer(_debounceDuration, () {
      saveDraft(draft);
    });
  }

  /// Save draft immediately (no debouncing)
  ///
  /// Use this for explicit save actions (e.g., user navigates away from form).
  Future<void> saveDraft(EventDraft draft) async {
    try {
      // Update lastSaved timestamp
      draft.lastSaved = DateTime.now();

      // Hive uses key 'current_draft' (single draft per user)
      await _draftsBox.put('current_draft', draft);
    } catch (e) {
      throw LocalDataSourceException('Failed to save draft: $e');
    }
  }

  /// Get current draft (returns null if no draft exists)
  EventDraft? getDraft() {
    try {
      return _draftsBox.get('current_draft');
    } catch (e) {
      throw LocalDataSourceException('Failed to get draft: $e');
    }
  }

  /// Delete current draft (called after successful event creation)
  Future<void> deleteDraft() async {
    try {
      await _draftsBox.delete('current_draft');

      // Cancel debounce timer if active
      _debounceTimer?.cancel();
    } catch (e) {
      throw LocalDataSourceException('Failed to delete draft: $e');
    }
  }

  /// Check if draft exists
  bool hasDraft() {
    return _draftsBox.containsKey('current_draft');
  }

  /// Get draft age (time since last save)
  ///
  /// Returns null if no draft exists.
  /// Useful for showing "Draft saved X minutes ago" UI.
  Duration? getDraftAge() {
    final draft = getDraft();
    if (draft == null) return null;

    return DateTime.now().difference(draft.lastSaved);
  }

  // =========================================================================
  // CLEANUP
  // =========================================================================

  /// Clear all drafts (for testing/debugging)
  Future<void> clearAllDrafts() async {
    try {
      await _draftsBox.clear();
      _debounceTimer?.cancel();
    } catch (e) {
      throw LocalDataSourceException('Failed to clear drafts: $e');
    }
  }

  /// Cancel debounce timer (cleanup on dispose)
  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// Exception thrown when local data source operation fails
class LocalDataSourceException implements Exception {
  final String message;

  LocalDataSourceException(this.message);

  @override
  String toString() => 'LocalDataSourceException: $message';
}
