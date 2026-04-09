import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';

/// Timestamp: "2 ORE FA" UPPERCASE (10px, #737373).
class EventCardTimestamp extends StatelessWidget {
  final DateTime createdAt;

  const EventCardTimestamp({super.key, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Text(
        formatTimestamp(createdAt).toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: NovaColors.grayDark,
        ),
      ),
    );
  }

  /// Format timestamp relative to now (e.g. "2 ore fa").
  static String formatTimestamp(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Adesso';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? "minuto" : "minuti"} fa';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "ora" : "ore"} fa';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "giorno" : "giorni"} fa';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "settimana" : "settimane"} fa';
    }
  }
}
