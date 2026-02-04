// Utility: DateFormatter
// Feature: 003-events-feed
// Purpose: Format dates and times for display (relative time + formatted dates)

class DateFormatter {
  // Private constructor to prevent instantiation (static utility class)
  DateFormatter._();

  /// Format DateTime as relative time (e.g., "2 hours ago", "Just now")
  /// Used for comments, likes, participations
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${minutes}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  /// Format event date and time (e.g., "Jan 15, 2025 at 3:00 PM")
  /// Used for event cards and detail screens
  static String eventDateTime(DateTime date, String time) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final month = monthNames[date.month - 1];
    final day = date.day;
    final year = date.year;

    return '$month $day, $year at $time';
  }

  /// Format date only (e.g., "Jan 15, 2025")
  /// Used for event date display without time
  static String formatDate(DateTime date) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final month = monthNames[date.month - 1];
    final day = date.day;
    final year = date.year;

    return '$month $day, $year';
  }

  /// Format time only (e.g., "3:00 PM")
  /// Converts HH:mm format to 12-hour format with AM/PM
  static String formatTime(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$hour12:$minute $period';
  }

  /// Format full timestamp (date + time)
  /// Used for created_at/updated_at display
  static String formatTimestamp(DateTime dateTime) {
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final month = monthNames[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$month $day, $year at $hour12:$minute $period';
  }

  /// Get day of week (e.g., "Monday", "Tuesday")
  static String dayOfWeek(DateTime date) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return dayNames[date.weekday - 1];
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Format event date with "Today" / "Tomorrow" labels
  /// (e.g., "Today at 3:00 PM", "Tomorrow at 3:00 PM", "Jan 15, 2025 at 3:00 PM")
  static String smartEventDateTime(DateTime date, String time) {
    if (isToday(date)) {
      return 'Today at ${formatTime(time)}';
    } else if (isTomorrow(date)) {
      return 'Tomorrow at ${formatTime(time)}';
    } else {
      return eventDateTime(date, time);
    }
  }

  /// Format event date for card (shorter format)
  /// (e.g., "Today 3:00 PM", "Tomorrow 3:00 PM", "Jan 15")
  static String cardEventDate(DateTime date, String time) {
    if (isToday(date)) {
      return 'Today ${formatTime(time)}';
    } else if (isTomorrow(date)) {
      return 'Tomorrow ${formatTime(time)}';
    } else {
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final month = monthNames[date.month - 1];
      return '$month ${date.day}';
    }
  }

  /// Parse ISO8601 date string to DateTime
  static DateTime parseIso8601(String dateString) {
    return DateTime.parse(dateString);
  }

  /// Format DateTime to ISO8601 string (for API calls)
  static String toIso8601(DateTime dateTime) {
    return dateTime.toIso8601String();
  }
}
