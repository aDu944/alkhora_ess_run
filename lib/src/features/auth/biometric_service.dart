import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> authenticate({required String reason}) async {
    try {
      final can = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!can) return true; // fall back to "no biometric required" if not supported
      return _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

