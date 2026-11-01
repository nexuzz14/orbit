import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _keyDbPassphrase = 'orbit_local_db_passphrase';
  static const _keySessionToken = 'orbit_session_token';

  /// Mendapatkan atau membuat passphrase acak untuk enkripsi database lokal (SQLCipher)
  static Future<String> getOrCreateDatabasePassphrase() async {
    String? passphrase = await _storage.read(key: _keyDbPassphrase);
    if (passphrase == null) {
      passphrase = const Uuid().v4() + const Uuid().v4();
      await _storage.write(key: _keyDbPassphrase, value: passphrase);
    }
    return passphrase;
  }

  static Future<void> saveSessionToken(String token) async {
    await _storage.write(key: _keySessionToken, value: token);
  }

  static Future<String?> getSessionToken() async {
    return await _storage.read(key: _keySessionToken);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
