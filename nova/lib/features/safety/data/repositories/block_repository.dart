import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_block.dart';

/// Repository for managing user blocks
class BlockRepository {
  BlockRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Block a user
  ///
  /// Returns the created block record
  /// Throws if user is already blocked or trying to block self
  Future<UserBlock> blockUser(String blockedUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }

    if (userId == blockedUserId) {
      throw Exception('Non puoi bloccare te stesso');
    }

    final response = await _supabase
        .from('user_blocks')
        .insert({
          'blocker_id': userId,
          'blocked_id': blockedUserId,
        })
        .select()
        .single();

    return UserBlock.fromJson(response);
  }

  /// Unblock a user
  ///
  /// Returns true if unblock was successful
  Future<bool> unblockUser(String blockedUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }

    await _supabase
        .from('user_blocks')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', blockedUserId);

    return true;
  }

  /// Get list of users blocked by current user
  ///
  /// Returns list with blocked user profile info
  Future<List<UserBlock>> getBlockedUsers() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Utente non autenticato');
    }

    final response = await _supabase
        .from('user_blocks')
        .select('''
          id,
          blocker_id,
          blocked_id,
          created_at,
          moderator_notified,
          notified_at,
          blocked:profiles!blocked_id (
            user_id,
            full_name,
            username,
            avatar_url
          )
        ''')
        .eq('blocker_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => UserBlock.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Check if current user has blocked a specific user
  Future<bool> isUserBlocked(String targetUserId) async {
    final result = await _supabase.rpc(
      'is_user_blocked',
      params: {'p_target_user_id': targetUserId},
    );

    return result as bool? ?? false;
  }

  /// Check if current user is blocked by another user
  Future<bool> isBlockedByUser(String targetUserId) async {
    final result = await _supabase.rpc(
      'is_blocked_by_user',
      params: {'p_target_user_id': targetUserId},
    );

    return result as bool? ?? false;
  }

  /// Get IDs of all users blocked by current user
  ///
  /// Useful for filtering feeds
  Future<List<String>> getBlockedUserIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', userId);

    return (response as List<dynamic>)
        .map((row) => row['blocked_id'] as String)
        .toList();
  }

  /// Get IDs of users who have blocked current user
  ///
  /// Useful for filtering who can see current user's content
  Future<List<String>> getBlockedByUserIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // This requires a special query since RLS restricts access
    // Use the is_blocked_by function for individual checks instead
    return [];
  }
}
