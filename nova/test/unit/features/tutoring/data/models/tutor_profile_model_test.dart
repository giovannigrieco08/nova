import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/tutoring/data/models/tutor_profile_model.dart';
import 'package:nova/features/tutoring/domain/entities/subject.dart';
import 'package:nova/features/tutoring/domain/entities/tutor_profile.dart';

void main() {
  final now = DateTime(2025, 6, 1);
  final updated = DateTime(2025, 6, 15);

  TutorProfileModel createModel({
    String id = 'tutor-001',
    String userId = 'user-001',
    String? bio = 'Bio text',
    List<String> subjects = const ['matematica', 'fisica'],
    double pricePerHour = 15.0,
    List<String> availabilityDays = const ['monday', 'wednesday'],
    String? timeSlot = '15:00-18:00',
    String? whatsappPhone = '393331234567',
    String? instagramUsername = 'tutor_mario',
    double rating = 4.5,
    int totalReviews = 10,
    bool isActive = true,
    String? authorName,
    String? authorAvatarUrl,
    String? authorClass,
    String? authorUsername,
  }) {
    return TutorProfileModel(
      id: id,
      userId: userId,
      bio: bio,
      subjects: subjects,
      pricePerHour: pricePerHour,
      availabilityDays: availabilityDays,
      timeSlot: timeSlot,
      whatsappPhone: whatsappPhone,
      instagramUsername: instagramUsername,
      rating: rating,
      totalReviews: totalReviews,
      isActive: isActive,
      createdAt: now,
      updatedAt: updated,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorClass: authorClass,
      authorUsername: authorUsername,
    );
  }

  group('TutorProfileModel', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields', () {
      final model = createModel();

      expect(model.id, 'tutor-001');
      expect(model.userId, 'user-001');
      expect(model.bio, 'Bio text');
      expect(model.subjects, ['matematica', 'fisica']);
      expect(model.pricePerHour, 15.0);
      expect(model.availabilityDays, ['monday', 'wednesday']);
      expect(model.timeSlot, '15:00-18:00');
      expect(model.whatsappPhone, '393331234567');
      expect(model.instagramUsername, 'tutor_mario');
      expect(model.isActive, true);
    });

    test('fromJson parses complete Supabase JSON', () {
      final json = {
        'id': 't1',
        'user_id': 'u1',
        'bio': 'My bio',
        'subjects': ['matematica', 'inglese'],
        'price_per_hour': 20,
        'availability_days': ['tuesday', 'friday'],
        'time_slot': '14:00-17:00',
        'whatsapp_phone': '393339876543',
        'instagram_username': 'teacher_ig',
        'rating': 4.8,
        'total_reviews': 25,
        'is_active': true,
        'created_at': '2025-06-01T00:00:00.000Z',
        'updated_at': '2025-06-15T00:00:00.000Z',
        'profiles': {
          'full_name': 'Mario Rossi',
          'avatar_url': 'https://example.com/a.jpg',
          'class': '5A',
          'username': 'mario.rossi',
        },
      };

      final model = TutorProfileModel.fromJson(json);

      expect(model.id, 't1');
      expect(model.subjects, ['matematica', 'inglese']);
      expect(model.pricePerHour, 20.0);
      expect(model.authorName, 'Mario Rossi');
      expect(model.authorAvatarUrl, 'https://example.com/a.jpg');
      expect(model.authorClass, '5A');
      expect(model.authorUsername, 'mario.rossi');
    });

    test('toJson produces correct output', () {
      final model = createModel();
      final json = model.toJson();

      expect(json['id'], 'tutor-001');
      expect(json['user_id'], 'user-001');
      expect(json['subjects'], ['matematica', 'fisica']);
      expect(json['price_per_hour'], 15.0);
      expect(json['created_at'], now.toIso8601String());
    });

    test('toInsertJson excludes read-only fields', () {
      final model = createModel();
      final json = model.toInsertJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('rating'), false);
      expect(json.containsKey('total_reviews'), false);
      expect(json.containsKey('created_at'), false);
      expect(json.containsKey('updated_at'), false);
      expect(json['user_id'], 'user-001');
      expect(json['subjects'], ['matematica', 'fisica']);
    });

    test('toUpdateJson excludes id and timestamps', () {
      final model = createModel();
      final json = model.toUpdateJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('user_id'), false);
      expect(json.containsKey('created_at'), false);
      expect(json.containsKey('updated_at'), false);
      expect(json['bio'], 'Bio text');
      expect(json['is_active'], true);
    });

    test('toEntity converts to domain entity with enum mapping', () {
      final model = createModel();
      final entity = model.toEntity();

      expect(entity, isA<TutorProfile>());
      expect(entity.id, 'tutor-001');
      expect(entity.subjects, [Subject.matematica, Subject.fisica]);
      expect(entity.availabilityDays,
          [AvailabilityDay.monday, AvailabilityDay.wednesday]);
      expect(entity.pricePerHour, 15.0);
    });

    test('fromEntity converts domain entity back to model', () {
      final model = createModel();
      final entity = model.toEntity();
      final backToModel = TutorProfileModel.fromEntity(entity);

      expect(backToModel.id, model.id);
      expect(backToModel.userId, model.userId);
      expect(backToModel.subjects, model.subjects);
      expect(backToModel.availabilityDays, model.availabilityDays);
    });

    test('equality is based on id', () {
      final a = createModel(id: 't1');
      final b = createModel(id: 't1', bio: 'Different');
      final c = createModel(id: 't2');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    // ===================== EDGE CASES =====================

    test('fromJson defaults missing optional fields', () {
      final json = {
        'id': 't1',
        'user_id': 'u1',
        'created_at': '2025-06-01T00:00:00.000Z',
        'updated_at': '2025-06-15T00:00:00.000Z',
      };

      final model = TutorProfileModel.fromJson(json);

      expect(model.bio, isNull);
      expect(model.subjects, isEmpty);
      expect(model.pricePerHour, 0.0);
      expect(model.availabilityDays, isEmpty);
      expect(model.rating, 0.0);
      expect(model.totalReviews, 0);
      expect(model.isActive, true);
      expect(model.authorName, isNull);
    });

    test('fromJson handles integer price_per_hour', () {
      final json = {
        'id': 't1',
        'user_id': 'u1',
        'price_per_hour': 20,
        'created_at': '2025-06-01T00:00:00.000Z',
        'updated_at': '2025-06-15T00:00:00.000Z',
      };

      final model = TutorProfileModel.fromJson(json);
      expect(model.pricePerHour, 20.0);
    });

    test('fromJson extracts profile fields from flat format as fallback', () {
      final json = {
        'id': 't1',
        'user_id': 'u1',
        'created_at': '2025-06-01T00:00:00.000Z',
        'updated_at': '2025-06-15T00:00:00.000Z',
        'author_full_name': 'Flat Name',
        'author_avatar_url': 'https://example.com/flat.jpg',
      };

      final model = TutorProfileModel.fromJson(json);
      expect(model.authorName, 'Flat Name');
      expect(model.authorAvatarUrl, 'https://example.com/flat.jpg');
    });

    test('toEntity handles unknown subject strings by filtering them out', () {
      final model = TutorProfileModel(
        id: 't1',
        userId: 'u1',
        subjects: ['matematica', 'nonexistent', 'fisica'],
        availabilityDays: ['monday', 'sunday'],
        createdAt: now,
        updatedAt: updated,
      );

      final entity = model.toEntity();
      expect(entity.subjects, [Subject.matematica, Subject.fisica]);
      expect(entity.availabilityDays, [AvailabilityDay.monday]);
    });
  });

  group('TutorProfileWithAuthor', () {
    test('fromJson creates extended model with author data', () {
      final json = {
        'id': 't1',
        'user_id': 'u1',
        'subjects': ['matematica'],
        'created_at': '2025-06-01T00:00:00.000Z',
        'updated_at': '2025-06-15T00:00:00.000Z',
        'profiles': {
          'full_name': 'Author Name',
          'username': 'author.name',
        },
      };

      final model = TutorProfileWithAuthor.fromJson(json);

      expect(model, isA<TutorProfileModel>());
      expect(model.authorName, 'Author Name');
      expect(model.authorUsername, 'author.name');
    });
  });
}
