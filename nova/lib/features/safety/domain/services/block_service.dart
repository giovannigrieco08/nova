import '../../data/models/user_block.dart';
import '../../data/repositories/block_repository.dart';

/// Service for managing user blocks
///
/// Provides business logic layer between UI and repository
class BlockService {
  BlockService({BlockRepository? repository})
      : _repository = repository ?? BlockRepository();

  final BlockRepository _repository;

  /// Block a user
  ///
  /// Returns the block record
  /// Throws if validation fails
  Future<UserBlock> blockUser(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('ID utente non valido');
    }

    // Check if already blocked
    final alreadyBlocked = await _repository.isUserBlocked(userId);
    if (alreadyBlocked) {
      throw UserAlreadyBlockedException();
    }

    return _repository.blockUser(userId);
  }

  /// Unblock a user
  ///
  /// Returns true if successful
  Future<bool> unblockUser(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('ID utente non valido');
    }

    return _repository.unblockUser(userId);
  }

  /// Get list of blocked users
  Future<List<UserBlock>> getBlockedUsers() async {
    return _repository.getBlockedUsers();
  }

  /// Check if user is blocked by current user
  Future<bool> isUserBlocked(String userId) async {
    return _repository.isUserBlocked(userId);
  }

  /// Check if current user is blocked by another user
  ///
  /// Used to show "Profile not available" message
  Future<bool> isBlockedByUser(String userId) async {
    return _repository.isBlockedByUser(userId);
  }

  /// Get list of blocked user IDs for feed filtering
  Future<List<String>> getBlockedUserIds() async {
    return _repository.getBlockedUserIds();
  }

  /// Check if current user can view another user's profile
  ///
  /// Returns false if blocked by that user
  Future<bool> canViewProfile(String userId) async {
    final isBlocked = await _repository.isBlockedByUser(userId);
    return !isBlocked;
  }
}

/// Exception thrown when trying to block an already blocked user
class UserAlreadyBlockedException implements Exception {
  @override
  String toString() => 'Utente già bloccato';
}
