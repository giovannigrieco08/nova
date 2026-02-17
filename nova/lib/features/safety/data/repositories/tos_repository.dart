import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tos_status.dart';

/// Repository for Terms of Service acceptance
class TosRepository {
  TosRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Current ToS version - update when ToS changes
  static const String currentTosVersion = '1.0.0';

  /// Get the current ToS acceptance status for the user
  Future<TosStatus> getTosStatus() async {
    final result = await _supabase.rpc('get_tos_status');

    if (result == null) {
      return TosStatus.initial();
    }

    return TosStatus.fromJson(result as Map<String, dynamic>);
  }

  /// Accept the Terms of Service
  ///
  /// Returns the acceptance response with timestamp
  Future<TosAcceptResponse> acceptTos({String? version}) async {
    final versionToAccept = version ?? currentTosVersion;

    final result = await _supabase.rpc(
      'accept_tos',
      params: {'p_version': versionToAccept},
    );

    return TosAcceptResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Get the URL for the ToS document
  ///
  /// Returns a public URL to the ToS markdown file
  String getTosDocumentUrl({String? version}) {
    final versionToGet = version ?? currentTosVersion;
    return _supabase.storage
        .from('public')
        .getPublicUrl('legal/tos-$versionToGet.md');
  }

  /// Check if user has accepted the current ToS
  Future<bool> hasAcceptedCurrentTos() async {
    final status = await getTosStatus();
    return status.canCreateContent;
  }

  /// Check if user needs to re-accept ToS due to version change
  Future<bool> needsToReaccept() async {
    final status = await getTosStatus();
    return status.needsReaccept;
  }
}
