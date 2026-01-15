// Repository Implementation: EventRepository
// Feature: 004-event-creation-moderation
// Purpose: Concrete implementation of EventRepository interface
//
// Responsibilities:
// - Orchestrate between remote (Supabase) and local (Hive) data sources
// - Handle image compression and upload to Storage
// - Convert between data models and domain entities
// - Implement offline-first draft persistence

import 'dart:io';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository_interface.dart';
import '../datasources/event_remote_datasource.dart';
import '../datasources/event_local_datasource.dart';
import '../models/event_model.dart';
import '../../../../core/utils/image_compressor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Concrete implementation of EventRepository
class EventRepositoryImpl implements EventRepository {
  final EventRemoteDataSource _remoteDataSource;
  final EventLocalDataSource _localDataSource;
  final SupabaseClient _supabase;

  EventRepositoryImpl({
    required EventRemoteDataSource remoteDataSource,
    required EventLocalDataSource localDataSource,
    required SupabaseClient supabase,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _supabase = supabase;

  // =========================================================================
  // READ OPERATIONS
  // =========================================================================

  @override
  Future<List<Event>> getApprovedEvents() async {
    final models = await _remoteDataSource.getApprovedEvents();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Event>> getMyEvents(String userId) async {
    final models = await _remoteDataSource.getMyEvents(userId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Event>> getPendingEvents() async {
    final models = await _remoteDataSource.getPendingEvents();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Event>> getCoOrganizedEvents(String userId) async {
    final models = await _remoteDataSource.getCoOrganizedEvents(userId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Event?> getEventById(String eventId) async {
    final model = await _remoteDataSource.getEventById(eventId);
    return model?.toEntity();
  }

  // =========================================================================
  // WRITE OPERATIONS
  // =========================================================================

  @override
  Future<Event> createEvent(
    Event event, {
    File? imageFile,
    List<String> pendingInvites = const [],
  }) async {
    try {
      // Step 1: Upload image if provided
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadEventImage(imageFile, event.id);
      }

      // Step 2: Create event model with image URL
      final eventModel = EventModel.fromEntity(
        event.copyWith(imageUrl: imageUrl),
      );

      // Step 3: Insert into Supabase
      final createdModel = await _remoteDataSource.createEvent(eventModel);

      // Step 4: Send collaboration invites to pending users
      for (final inviteeId in pendingInvites) {
        await _sendCollaborationInvite(
          eventId: createdModel.id,
          inviteeId: inviteeId,
          inviterId: event.creatorId,
        );
      }

      // Step 5: Delete draft on success
      await _localDataSource.deleteDraft();

      return createdModel.toEntity();
    } catch (e) {
      throw EventRepositoryException('Failed to create event: $e');
    }
  }

  /// Send collaboration invite to a user
  Future<void> _sendCollaborationInvite({
    required String eventId,
    required String inviteeId,
    required String inviterId,
  }) async {
    try {
      await _supabase.from('collaboration_invites').insert({
        'event_id': eventId,
        'inviter_id': inviterId,
        'invitee_id': inviteeId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - don't block event creation for invite failure
    }
  }

  @override
  Future<Event> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      final updatedModel = await _remoteDataSource.updateEvent(eventId, updates);
      return updatedModel.toEntity();
    } catch (e) {
      throw EventRepositoryException('Failed to update event: $e');
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      // Get event to delete image from storage
      final event = await getEventById(eventId);
      if (event?.imageUrl != null) {
        await deleteEventImage(event!.imageUrl!);
      }

      await _remoteDataSource.deleteEvent(eventId);
    } catch (e) {
      throw EventRepositoryException('Failed to delete event: $e');
    }
  }

  // =========================================================================
  // MODERATION OPERATIONS
  // =========================================================================

  @override
  Future<void> approveEvent(String eventId) async {
    try {
      await _remoteDataSource.approveEvent(eventId);
    } catch (e) {
      throw EventRepositoryException('Failed to approve event: $e');
    }
  }

  @override
  Future<void> rejectEvent(String eventId, String rejectionReason) async {
    try {
      await _remoteDataSource.rejectEvent(eventId, rejectionReason);
    } catch (e) {
      throw EventRepositoryException('Failed to reject event: $e');
    }
  }

  // =========================================================================
  // CO-ORGANIZER OPERATIONS
  // =========================================================================

  @override
  Future<void> addCoOrganizer(String eventId, String userId) async {
    try {
      await _remoteDataSource.addCoOrganizer(eventId, userId);
    } catch (e) {
      throw EventRepositoryException('Failed to add co-organizer: $e');
    }
  }

  @override
  Future<void> removeCoOrganizer(String eventId, String userId) async {
    try {
      await _remoteDataSource.removeCoOrganizer(eventId, userId);
    } catch (e) {
      throw EventRepositoryException('Failed to remove co-organizer: $e');
    }
  }

  // =========================================================================
  // STORAGE OPERATIONS
  // =========================================================================

  @override
  Future<String> uploadEventImage(File imageFile, String eventId) async {
    try {
      // Step 1: Compress image (WebP → JPEG fallback, max 200KB)
      final compressedBytes = await ImageCompressor.compressImage(imageFile);

      // Step 2: Determine file extension from compressed bytes
      final extension = ImageCompressor.getImageExtension(compressedBytes);

      // Step 3: Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$eventId/$timestamp.$extension';

      // Step 4: Upload to Supabase Storage bucket 'event-images'
      await _supabase.storage.from('event-images').uploadBinary(
            fileName,
            compressedBytes,
            fileOptions: FileOptions(
              contentType: extension == 'webp' ? 'image/webp' : 'image/jpeg',
              upsert: false, // Prevent overwrites
            ),
          );

      // Step 5: Get public URL
      final publicUrl = _supabase.storage
          .from('event-images')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw EventRepositoryException('Failed to upload image: $e');
    }
  }

  @override
  Future<void> deleteEventImage(String imageUrl) async {
    try {
      // Extract file path from public URL
      // Example URL: https://{project}.supabase.co/storage/v1/object/public/event-images/123/456.jpg
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find 'event-images' bucket index
      final bucketIndex = pathSegments.indexOf('event-images');
      if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
        throw EventRepositoryException('Invalid image URL format');
      }

      // Extract file path after bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete from storage
      await _supabase.storage.from('event-images').remove([filePath]);
    } catch (e) {
      // Don't throw on delete failure - image might already be deleted
    }
  }
}

/// Exception thrown when repository operation fails
class EventRepositoryException implements Exception {
  final String message;

  EventRepositoryException(this.message);

  @override
  String toString() => 'EventRepositoryException: $message';
}
