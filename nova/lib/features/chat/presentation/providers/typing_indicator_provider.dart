import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/features/chat/presentation/providers/chat_providers.dart';

/// Manages typing indicator state via Supabase Presence channel.
///
/// Features:
/// - Broadcasts when current user starts/stops typing
/// - Tracks who is currently typing
/// - Auto-timeout after 3 seconds of inactivity
/// - Debounced updates (300ms)
class TypingIndicatorNotifier extends StateNotifier<TypingIndicatorState> {
  final SupabaseClient _supabase;
  final String _currentUserId;
  final String _currentUserName;

  RealtimeChannel? _presenceChannel;
  Timer? _typingTimer;
  DateTime? _lastTypingUpdate;

  static const _typingTimeout = Duration(seconds: 3);
  static const _debounceInterval = Duration(milliseconds: 300);

  TypingIndicatorNotifier({
    required SupabaseClient supabase,
    required String currentUserId,
    required String currentUserName,
  })  : _supabase = supabase,
        _currentUserId = currentUserId,
        _currentUserName = currentUserName,
        super(const TypingIndicatorState());

  /// Initialize presence channel
  Future<void> initialize() async {
    _presenceChannel = _supabase.channel('global-chat:presence');

    _presenceChannel!.onPresenceSync((payload) {
      _handlePresenceSync();
    });

    _presenceChannel!.onPresenceJoin((payload) {
      _handlePresenceChange();
    });

    _presenceChannel!.onPresenceLeave((payload) {
      _handlePresenceChange();
    });

    await _presenceChannel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track current user
        await _presenceChannel!.track({
          'user_id': _currentUserId,
          'user_name': _currentUserName,
          'typing': false,
        });
      }
    });
  }

  void _handlePresenceSync() {
    _updateTypingUsers();
  }

  void _handlePresenceChange() {
    _updateTypingUsers();
  }

  void _updateTypingUsers() {
    final presenceState = _presenceChannel?.presenceState();
    final typingUsers = <TypingUser>[];

    if (presenceState != null && presenceState is Map<String, List<dynamic>>) {
      final presences = presenceState as Map<String, List<dynamic>>;
      for (final entry in presences.entries) {
        for (final presence in entry.value) {
          if (presence is Presence) {
            final payload = presence.payload;
            if (payload['typing'] == true &&
                payload['user_id'] != _currentUserId) {
              typingUsers.add(TypingUser(
                userId: payload['user_id'] as String,
                userName: payload['user_name'] as String,
              ));
            }
          }
        }
      }
    }

    state = state.copyWith(typingUsers: typingUsers);
  }

  /// Call when user starts typing
  Future<void> startTyping() async {
    final now = DateTime.now();

    // Debounce updates
    if (_lastTypingUpdate != null &&
        now.difference(_lastTypingUpdate!) < _debounceInterval) {
      return;
    }
    _lastTypingUpdate = now;

    // Update presence to typing
    await _presenceChannel?.track({
      'user_id': _currentUserId,
      'user_name': _currentUserName,
      'typing': true,
    });

    // Reset auto-stop timer
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, stopTyping);
  }

  /// Call when user stops typing
  Future<void> stopTyping() async {
    _typingTimer?.cancel();
    _typingTimer = null;

    await _presenceChannel?.track({
      'user_id': _currentUserId,
      'user_name': _currentUserName,
      'typing': false,
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}

/// State for typing indicators
class TypingIndicatorState {
  final List<TypingUser> typingUsers;

  const TypingIndicatorState({
    this.typingUsers = const [],
  });

  TypingIndicatorState copyWith({
    List<TypingUser>? typingUsers,
  }) {
    return TypingIndicatorState(
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }

  /// Whether anyone is typing
  bool get hasTypingUsers => typingUsers.isNotEmpty;

  /// Formatted typing indicator text
  ///
  /// - "Mario sta scrivendo..."
  /// - "Mario e Giulia stanno scrivendo..."
  /// - "Mario, Giulia e altri 2 stanno scrivendo..."
  String get typingText {
    if (typingUsers.isEmpty) return '';

    final names = typingUsers.map((u) => u.userName.split(' ').first).toList();

    if (names.length == 1) {
      return '${names[0]} sta scrivendo...';
    }

    if (names.length == 2) {
      return '${names[0]} e ${names[1]} stanno scrivendo...';
    }

    if (names.length == 3) {
      return '${names[0]}, ${names[1]} e ${names[2]} stanno scrivendo...';
    }

    final othersCount = names.length - 2;
    return '${names[0]}, ${names[1]} e altri $othersCount stanno scrivendo...';
  }
}

/// A user who is currently typing
class TypingUser {
  final String userId;
  final String userName;

  const TypingUser({
    required this.userId,
    required this.userName,
  });
}

/// Provider for typing indicator
final typingIndicatorProvider = StateNotifierProvider.autoDispose<
    TypingIndicatorNotifier, TypingIndicatorState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  // TODO: Get current user name from profile provider
  const currentUserName = 'Utente';

  final notifier = TypingIndicatorNotifier(
    supabase: supabase,
    currentUserId: currentUserId,
    currentUserName: currentUserName,
  );

  notifier.initialize();

  return notifier;
});
