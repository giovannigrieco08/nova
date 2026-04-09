import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/comments_repository_interface.dart';
import '../datasources/comments_remote_datasource.dart';
import '../datasources/comments_local_datasource.dart';
import '../repositories/comments_repository.dart';

export '../repositories/comments_repository.dart' show CommentsRepository;

/// Provider for CommentsRepository
final commentsRepositoryProvider = Provider<CommentsRepositoryInterface>((ref) {
  final supabase = Supabase.instance.client;
  final remoteDataSource = CommentsRemoteDataSource(supabase);
  final localDataSource = CommentsLocalDataSource();

  // Initialize local data source
  localDataSource.init();

  return CommentsRepository(remoteDataSource, localDataSource);
});
