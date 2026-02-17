import '../../data/models/tos_status.dart';
import '../../data/repositories/tos_repository.dart';

/// Service for Terms of Service operations
///
/// Provides business logic for ToS acceptance and validation
class TosService {
  TosService({TosRepository? repository})
      : _repository = repository ?? TosRepository();

  final TosRepository _repository;

  /// Get current ToS status
  Future<TosStatus> getTosStatus() async {
    return _repository.getTosStatus();
  }

  /// Accept the current ToS
  Future<TosAcceptResponse> acceptTos() async {
    return _repository.acceptTos();
  }

  /// Check if user can create content
  ///
  /// Returns true if ToS is accepted and current
  Future<bool> canCreateContent() async {
    final status = await _repository.getTosStatus();
    return status.canCreateContent;
  }

  /// Check if user needs to accept or re-accept ToS
  Future<bool> needsTosAcceptance() async {
    final status = await _repository.getTosStatus();
    return !status.hasAccepted || status.needsReaccept;
  }

  /// Get URL for ToS document
  String getTosDocumentUrl() {
    return _repository.getTosDocumentUrl();
  }

  /// Get current ToS version
  String get currentVersion => TosRepository.currentTosVersion;
}
