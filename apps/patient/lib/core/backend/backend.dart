import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Connects the app to ApneDoctors' Supabase project.
///
/// Only reads a saved session from the phone; it never waits for the network, so the native splash
/// is never held up by a slow or missing connection (EC-LAUNCH-11).
Future<void> connectBackend() => Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey);

/// The one Supabase client. Everything that talks to the backend reads it from here.
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Whether a session is saved on this phone (read once, at launch). False when the backend hasn't started (tests).
final signedInProvider = Provider<bool>((ref) {
  try {
    return ref.read(supabaseProvider).auth.currentSession != null;
  } catch (_) {
    return false;
  }
});
