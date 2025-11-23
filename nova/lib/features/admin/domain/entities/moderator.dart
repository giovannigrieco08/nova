// =====================================================================
// Moderator Entity - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Moderator entity with user info and statistics
// Architecture: Freezed entity with JSON serialization
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'moderator.freezed.dart';
part 'moderator.g.dart';

/// Moderator entity with statistics
///
/// Combines user info from profiles table with stats from moderator_stats table.
/// Used in Admin Panel to display moderator list with performance metrics.
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

/// Extension methods for Moderator convenience
extension ModeratorX on Moderator {
  /// Whether moderator has reviewed in the last 7 days
  bool get isActive {
    if (lastReviewAt == null) return false;
    return DateTime.now().difference(lastReviewAt!).inDays <= 7;
  }

  /// Human-readable last activity time
  String get lastActivityText {
    if (lastReviewAt == null) return 'Mai';
    final diff = DateTime.now().difference(lastReviewAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m fa';
    if (diff.inHours < 24) return '${diff.inHours}h fa';
    if (diff.inDays < 7) return '${diff.inDays}g fa';
    return '${(diff.inDays / 7).floor()}w fa';
  }
}
