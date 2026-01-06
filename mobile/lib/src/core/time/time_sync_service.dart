import 'package:ntp/ntp.dart';

import '../storage/secure_kv.dart';

class TimeSyncService {
  TimeSyncService._(this._offset, this._lastSync);

  Duration _offset;
  DateTime? _lastSync;

  /// Load cached NTP offset (if any).
  static Future<TimeSyncService> create() async {
    final rawOffsetMs = await SecureKv.read(SecureKeys.ntpOffsetMs);
    final rawLastSyncIso = await SecureKv.read(SecureKeys.ntpLastSyncIso);
    final offsetMs = int.tryParse(rawOffsetMs ?? '');
    final lastSync = rawLastSyncIso != null ? DateTime.tryParse(rawLastSyncIso) : null;
    return TimeSyncService._(
      Duration(milliseconds: offsetMs ?? 0),
      lastSync,
    );
  }

  bool get hasTrustedOffset => _lastSync != null;

  DateTime? get lastSyncUtc => _lastSync;

  /// Current time adjusted by last known NTP offset.
  DateTime nowUtc() => DateTime.now().toUtc().add(_offset);

  /// Refresh NTP offset. Safe to call often; the caller should throttle.
  Future<void> sync({bool force = false}) async {
    // Throttle NTP sync to avoid excessive network usage.
    final last = _lastSync;
    if (!force && last != null) {
      final age = DateTime.now().toUtc().difference(last);
      if (age < const Duration(minutes: 10)) return;
    }

    final localUtc = DateTime.now().toUtc();
    final offsetMs = await NTP.getNtpOffset(localTime: localUtc);
    _offset = Duration(milliseconds: offsetMs);
    _lastSync = DateTime.now().toUtc();

    await SecureKv.write(SecureKeys.ntpOffsetMs, offsetMs.toString());
    await SecureKv.write(SecureKeys.ntpLastSyncIso, _lastSync!.toIso8601String());
  }
}

