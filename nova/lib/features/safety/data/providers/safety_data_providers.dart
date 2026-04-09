import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/block_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/content_filter_repository.dart';
import '../repositories/tos_repository.dart';
import '../../domain/services/block_service.dart';
import '../../domain/services/report_service.dart';
import '../../domain/services/content_filter_service.dart';
import '../../domain/services/tos_service.dart';

// =============================================================================
// Block Providers
// =============================================================================

/// Provider for BlockRepository
final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository();
});

/// Provider for BlockService
final blockServiceProvider = Provider<BlockService>((ref) {
  return BlockService(
    repository: ref.watch(blockRepositoryProvider),
  );
});

// =============================================================================
// Report Providers
// =============================================================================

/// Provider for ReportRepository
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

/// Provider for ReportService
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(
    repository: ref.watch(reportRepositoryProvider),
  );
});

// =============================================================================
// Content Filter Providers
// =============================================================================

/// Provider for ContentFilterRepository
final contentFilterRepositoryProvider =
    Provider<ContentFilterRepository>((ref) {
  return ContentFilterRepository();
});

/// Provider for ContentFilterService
final contentFilterServiceProvider = Provider<ContentFilterService>((ref) {
  return ContentFilterService(
    repository: ref.watch(contentFilterRepositoryProvider),
  );
});

// =============================================================================
// ToS Providers
// =============================================================================

/// Provider for TosRepository
final tosRepositoryProvider = Provider<TosRepository>((ref) {
  return TosRepository();
});

/// Provider for TosService
final tosServiceProvider = Provider<TosService>((ref) {
  return TosService(
    repository: ref.watch(tosRepositoryProvider),
  );
});
