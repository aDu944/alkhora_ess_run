import 'package:uuid/uuid.dart';

import '../storage/secure_kv.dart';

class DeviceId {
  static const _uuid = Uuid();

  /// Returns a stable per-install identifier for idempotency and auditing.
  ///
  /// Note: this is intentionally *not* a hardware identifier.
  static Future<String> getOrCreate() async {
    final existing = await SecureKv.read(SecureKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await SecureKv.write(SecureKeys.deviceId, id);
    return id;
  }
}

