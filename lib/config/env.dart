/// Runtime configuration injected at build time.
///
/// Secrets are NOT hardcoded in source. They are supplied through
/// `--dart-define-from-file=env/env.json` (see `env/env.example.json`).
/// `env/env.json` is git-ignored so keys never reach the repository.
///
/// If no Supabase keys are provided the app starts in **Demo mode**, which
/// keeps all data on the device so the app can still be demonstrated offline.
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Supabase *publishable* key (or the legacy "anon" key). It is safe to
  /// ship in an app because Row Level Security protects the data, but it is
  /// still kept out of source control.
  static const String supabaseKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// All traffic to the backend must be encrypted (TLS).
  static bool get backendUrlIsSecure => supabaseUrl.startsWith('https://');
}
