/// Profile statistics entity
///
/// Contains user activity statistics for display in profile.
library;

class ProfileStats {
  final int eventsCreatedCount;
  final int participationsCount;

  const ProfileStats({
    required this.eventsCreatedCount,
    required this.participationsCount,
  });

  /// Create empty stats
  factory ProfileStats.empty() {
    return const ProfileStats(
      eventsCreatedCount: 0,
      participationsCount: 0,
    );
  }

  /// Create from JSON map (Supabase response)
  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      eventsCreatedCount: json['events_created_count'] as int? ?? 0,
      participationsCount: json['participations_count'] as int? ?? 0,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'events_created_count': eventsCreatedCount,
      'participations_count': participationsCount,
    };
  }

  /// Total activity count
  int get totalActivity => eventsCreatedCount + participationsCount;

  /// Copy with modified values
  ProfileStats copyWith({
    int? eventsCreatedCount,
    int? participationsCount,
  }) {
    return ProfileStats(
      eventsCreatedCount: eventsCreatedCount ?? this.eventsCreatedCount,
      participationsCount: participationsCount ?? this.participationsCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStats &&
        other.eventsCreatedCount == eventsCreatedCount &&
        other.participationsCount == participationsCount;
  }

  @override
  int get hashCode => eventsCreatedCount.hashCode ^ participationsCount.hashCode;

  @override
  String toString() {
    return 'ProfileStats(eventsCreatedCount: $eventsCreatedCount, participationsCount: $participationsCount)';
  }
}
