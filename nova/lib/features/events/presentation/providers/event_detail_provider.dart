// Feature: Event Detail Provider
// Purpose: Fetch single event by ID for EventDetailScreen
// Used by: Deep link navigation and event detail view

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/event.dart';
import 'repository_providers.dart';

/// Provider for fetching a single event by ID
///
/// Returns:
/// - Event if found and user has permission to view
/// - null if event not found or user lacks permission
///
/// Permission rules:
/// - 'approved' events: visible to all users
/// - 'pending' events: visible only to creator and moderators
/// - 'rejected' events: visible only to creator and moderators
final eventDetailProvider =
    FutureProvider.family<Event?, String>((ref, eventId) async {
  final repository = ref.read(eventRepositoryProvider);

  try {
    return await repository.getEventById(eventId);
  } catch (e) {
    // Event not found or permission denied
    return null;
  }
});
