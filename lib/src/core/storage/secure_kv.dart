import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKv {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> init() async {
    // Placeholder for future migrations.
  }

  static Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  static Future<String?> read(String key) => _storage.read(key: key);
  static Future<void> delete(String key) => _storage.delete(key: key);
  static Future<void> deleteAll() => _storage.deleteAll();
}

class SecureKeys {
  static const baseUrl = 'baseUrl';
  static const lastUser = 'lastUser';
  static const biometricEnabled = 'biometricEnabled';
  static const ntpOffsetMs = 'ntpOffsetMs';
  static const ntpLastSyncIso = 'ntpLastSyncIso';
  static const rememberedUsername = 'rememberedUsername';
  static const rememberMeEnabled = 'rememberMeEnabled';
}

