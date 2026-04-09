import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart';

export 'package:nova/features/chat/data/datasources/chat_remote_datasource.dart'
    show ChatRemoteDataSource;

// =============================================================================
// Data Layer Providers
// =============================================================================

/// Hive box for pending messages (offline queue)
/// Note: Box is opened in main.dart before runApp(), so it's guaranteed to be available
final pendingMessagesBoxProvider = Provider<Box<Map<dynamic, dynamic>>>((ref) {
  return Hive.box<Map<dynamic, dynamic>>('chat_pending_messages');
});

/// Remote data source provider
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ChatRemoteDataSource(supabase);
});

/// Chat repository provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remoteDataSource = ref.watch(chatRemoteDataSourceProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final box = ref.watch(pendingMessagesBoxProvider);

  return ChatRepositoryImpl(
    remoteDataSource: remoteDataSource,
    supabase: supabase,
    pendingMessagesBox: box,
  );
});
