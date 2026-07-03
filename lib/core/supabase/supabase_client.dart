import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initialises the Supabase SDK using the credentials from `.env.local`.
///
/// Must be awaited once during app start-up (in `main`) before any Supabase
/// call is made. [Env.load] must have completed first.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
}

/// Shortcut to the shared Supabase client for use across the app once
/// [initSupabase] has completed, e.g. `supabase.from('table').select()`.
SupabaseClient get supabase => Supabase.instance.client;
