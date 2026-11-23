import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'data/backend.dart';
import 'data/demo_backend.dart';
import 'data/local_cache.dart';
import 'data/secure_session_storage.dart';
import 'data/supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = LocalCache(await SharedPreferences.getInstance());

  final Backend backend;
  if (Env.hasBackend) {
    if (!Env.backendUrlIsSecure) {
      throw StateError('SUPABASE_URL must start with https:// (encrypted connection).');
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
      authOptions: FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
    );
    backend = SupabaseBackend(Supabase.instance.client);
  } else {
    backend = DemoBackend(cache);
  }

  runApp(BossBotakApp(backend: backend, cache: cache));
}
