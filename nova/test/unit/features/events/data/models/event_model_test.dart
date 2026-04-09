import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  final now = DateTime(2025, 6, 15, 14, 30);

  EventModel createTestModel({
    String status = 'approved',
    Map<String, dynamic>? creatorData,
  }) {
    return EventModel(
      id: 'event-001',
      title: 'Torneo di Calcetto',
      description: 'Torneo organizzato dalla 4A al campetto',
      eventDate: now,
      location: 'Aula Magna',
      imageUrl: 'https://example.com/img.jpg',
      creatorId: TestUserIds.student1,
      coOrganizers: [TestUserIds.student2],
      status: status,
      createdAt: now,
      updatedAt: now,
      latitude: 45.4642,
      longitude: 9.1900,
      placeId: 'place-123',
      creatorData: creatorData,
    );
  }

  group('EventModel', () {
    // =====================================================================
    // Happy Path Tests (H:4)
    // =====================================================================

    test('should create EventModel with all fields', () {
      final model = createTestModel();

      expect(model.id, 'event-001');
      expect(model.title, 'Torneo di Calcetto');
      expect(model.creatorId, TestUserIds.student1);
      expect(model.coOrganizers, [TestUserIds.student2]);
      expect(model.status, 'approved');
      expect(model.latitude, 45.4642);
      expect(model.longitude, 9.1900);
    });

    test('toEntity converts model to domain Event correctly', () {
      final model = createTestModel(
        creatorData: {
          'full_name': 'Mario Rossi',
          'class': '4A',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      );

      final entity = model.toEntity();

      expect(entity, isA<Event>());
      expect(entity.id, model.id);
      expect(entity.title, model.title);
      expect(entity.status, EventStatus.approved);
      expect(entity.creatorName, 'Mario Rossi');
      expect(entity.creatorClass, '4A');
      expect(entity.creatorAvatarUrl, 'https://example.com/avatar.jpg');
      expect(entity.latitude, 45.4642);
    });

    test('fromEntity creates model from domain Event', () {
      final entity = TestEvents.approvedEvent();
      final model = EventModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.title, entity.title);
      expect(model.status, 'approved');
      expect(model.creatorId, entity.creatorId);
    });

    test('copyWith updates specific fields while preserving others', () {
      final model = createTestModel();
      final updated = model.copyWith(
        title: 'New Title',
        status: 'rejected',
        rejectionReason: 'Not appropriate',
      );

      expect(updated.title, 'New Title');
      expect(updated.status, 'rejected');
      expect(updated.rejectionReason, 'Not appropriate');
      expect(updated.id, model.id);
      expect(updated.description, model.description);
      expect(updated.creatorId, model.creatorId);
    });

    // =====================================================================
    // Edge Case Tests (E:5)
    // =====================================================================

    test('toEntity with null creatorData sets creator info to null', () {
      final model = createTestModel(creatorData: null);
      final entity = model.toEntity();

      expect(entity.creatorName, isNull);
      expect(entity.creatorClass, isNull);
      expect(entity.creatorAvatarUrl, isNull);
    });

    test('toEntity with empty creatorData sets creator info to null', () {
      final model = createTestModel(creatorData: {});
      final entity = model.toEntity();

      expect(entity.creatorName, isNull);
      expect(entity.creatorClass, isNull);
      expect(entity.creatorAvatarUrl, isNull);
    });

    test('equality is based on id only', () {
      final model1 = createTestModel();
      final model2 = EventModel(
        id: 'event-001',
        title: 'Different Title',
        description: 'Different description',
        eventDate: now.add(const Duration(days: 5)),
        creatorId: 'different-creator',
        coOrganizers: [],
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      expect(model1, equals(model2));
      expect(model1.hashCode, model2.hashCode);
    });

    test('EventModel with null optional fields', () {
      final model = EventModel(
        id: 'event-minimal',
        title: 'Minimal Event',
        description: 'Just the basics',
        eventDate: now,
        creatorId: TestUserIds.student1,
        coOrganizers: [],
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      expect(model.location, isNull);
      expect(model.imageUrl, isNull);
      expect(model.rejectionReason, isNull);
      expect(model.moderatedBy, isNull);
      expect(model.moderatedAt, isNull);
      expect(model.latitude, isNull);
      expect(model.longitude, isNull);
      expect(model.placeId, isNull);
      expect(model.creatorData, isNull);
    });

    test('fromEntity roundtrip preserves core data', () {
      final entity = TestEvents.approvedEvent();
      final model = EventModel.fromEntity(entity);
      final restored = model.toEntity();

      expect(restored.id, entity.id);
      expect(restored.title, entity.title);
      expect(restored.description, entity.description);
      expect(restored.creatorId, entity.creatorId);
      expect(restored.status, entity.status);
    });
  });
}
