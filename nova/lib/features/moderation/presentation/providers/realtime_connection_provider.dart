// =====================================================================
// Realtime Connection Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Stub for Realtime connection state (Supabase SDK doesn't expose connection state)
// Architecture: Provider assuming always connected (Supabase has automatic reconnection)
// =====================================================================
// NOTE: Supabase Flutter SDK doesn't expose connectionStream() in public API.
//       For MVP, we assume connection is always available and rely on Supabase's
//       built-in automatic reconnection logic.
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Realtime connection state monitoring
///
/// NOTE: This is a stub provider. Supabase Realtime has built-in automatic
/// reconnection, so we assume the connection is always available for MVP.
///
/// Future enhancement: Implement custom connection monitoring via channel status.
final realtimeConnectionProvider = Provider.autoDispose<bool>((ref) {
  // Assume always connected - Supabase handles reconnection automatically
  return true;
});
