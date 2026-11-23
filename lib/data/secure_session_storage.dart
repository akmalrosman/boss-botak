import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the Supabase auth session (access + refresh tokens) in the
/// platform's secure storage (Android Keystore-backed EncryptedSharedPreferences
/// / iOS Keychain) instead of plain SharedPreferences.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage();

  static const _key = 'bb.supabase.session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
