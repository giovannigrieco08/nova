import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/tutoring/domain/entities/tutor_profile.dart';
import 'package:nova/features/tutoring/domain/entities/subject.dart';

void main() {
  final now = DateTime(2025, 6, 1);
  final updated = DateTime(2025, 6, 15);

  TutorProfile createProfile({
    String id = 'tutor-001',
    String userId = 'user-001',
    String? bio = 'Tutor bio',
    List<Subject> subjects = const [Subject.matematica, Subject.fisica],
    double pricePerHour = 15.0,
    List<AvailabilityDay> availabilityDays = const [
      AvailabilityDay.monday,
      AvailabilityDay.wednesday,
    ],
    String? whatsappPhone = '393331234567',
    String? instagramUsername = 'mario_tutor',
    double rating = 4.5,
    int totalReviews = 10,
    bool isActive = true,
  }) {
    return TutorProfile(
      id: id,
      userId: userId,
      bio: bio,
      subjects: subjects,
      pricePerHour: pricePerHour,
      availabilityDays: availabilityDays,
      whatsappPhone: whatsappPhone,
      instagramUsername: instagramUsername,
      rating: rating,
      totalReviews: totalReviews,
      isActive: isActive,
      createdAt: now,
      updatedAt: updated,
    );
  }

  group('TutorProfile', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields and computed properties', () {
      final profile = createProfile();

      expect(profile.id, 'tutor-001');
      expect(profile.userId, 'user-001');
      expect(profile.isFree, false);
      expect(profile.hasWhatsApp, true);
      expect(profile.hasInstagram, true);
      expect(profile.priceDisplay, '\u20ac15/ora');
      expect(profile.subjectsDisplay, 'Matematica, Fisica');
      expect(profile.availabilityDisplay, 'Luned\u00ec, Mercoled\u00ec');
      expect(profile.whatsappUrl, 'https://wa.me/393331234567');
      expect(profile.instagramUrl, 'https://instagram.com/mario_tutor');
    });

    test('free tutor shows Gratis and isFree is true', () {
      final profile = createProfile(pricePerHour: 0.0);

      expect(profile.isFree, true);
      expect(profile.priceDisplay, 'Gratis');
    });

    // ===================== EDGE CASES =====================

    test('hasWhatsApp returns false when null or empty', () {
      expect(createProfile(whatsappPhone: null).hasWhatsApp, false);
      expect(createProfile(whatsappPhone: '').hasWhatsApp, false);
    });

    test('hasInstagram returns false when null or empty', () {
      expect(createProfile(instagramUsername: null).hasInstagram, false);
      expect(createProfile(instagramUsername: '').hasInstagram, false);
    });

    test('whatsappUrl and instagramUrl return null when not set', () {
      final profile =
          createProfile(whatsappPhone: null, instagramUsername: null);

      expect(profile.whatsappUrl, isNull);
      expect(profile.instagramUrl, isNull);
    });

    test('empty subjects and availability produce empty display strings', () {
      final profile = createProfile(
        subjects: const [],
        availabilityDays: const [],
      );

      expect(profile.subjectsDisplay, '');
      expect(profile.availabilityDisplay, '');
    });
  });
}
