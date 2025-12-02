import 'package:freezed_annotation/freezed_annotation.dart';
import 'subject.dart';

part 'tutor_profile.freezed.dart';

/// TutorProfile entity representing a student's tutoring profile.
///
/// Contains information about subjects offered, pricing, availability,
/// and contact methods for peer-to-peer tutoring.
@freezed
class TutorProfile with _$TutorProfile {
  const TutorProfile._();

  const factory TutorProfile({
    required String id,
    required String userId,
    String? bio,
    @Default([]) List<Subject> subjects,
    @Default(0.0) double pricePerHour,
    @Default([]) List<AvailabilityDay> availabilityDays,
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
    @Default(0.0) double rating,
    @Default(0) int totalReviews,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TutorProfile;

  /// Whether the tutor offers free tutoring.
  bool get isFree => pricePerHour == 0;

  /// Whether WhatsApp contact is available.
  bool get hasWhatsApp => whatsappPhone != null && whatsappPhone!.isNotEmpty;

  /// Whether Instagram contact is available.
  bool get hasInstagram =>
      instagramUsername != null && instagramUsername!.isNotEmpty;

  /// Formatted price display string.
  String get priceDisplay =>
      isFree ? 'Gratis' : '€${pricePerHour.toStringAsFixed(0)}/ora';

  /// Comma-separated list of subject display names.
  String get subjectsDisplay => subjects.map((s) => s.displayName).join(', ');

  /// Comma-separated list of availability day display names.
  String get availabilityDisplay =>
      availabilityDays.map((d) => d.displayName).join(', ');

  /// WhatsApp deep link URL.
  String? get whatsappUrl =>
      hasWhatsApp ? 'https://wa.me/$whatsappPhone' : null;

  /// Instagram deep link URL.
  String? get instagramUrl =>
      hasInstagram ? 'https://instagram.com/$instagramUsername' : null;
}
