import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> canAuthenticate() async {
    try {
      debugPrint('BiometricService.canAuthenticate: Starting check...');
      final isSupported = await _auth.isDeviceSupported();
      debugPrint('BiometricService.canAuthenticate: isDeviceSupported = $isSupported');
      
      if (!isSupported) {
        debugPrint('BiometricService.canAuthenticate: Device not supported');
        return false;
      }
      
      final canCheck = await _auth.canCheckBiometrics;
      debugPrint('BiometricService.canAuthenticate: canCheckBiometrics = $canCheck');
      
      final availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint('BiometricService.canAuthenticate: availableBiometrics = $availableBiometrics');
      
      // Return true if device is supported and has biometrics available
      // On emulators, canCheckBiometrics might be false but device is still supported
      final result = isSupported && (canCheck || availableBiometrics.isNotEmpty);
      debugPrint('BiometricService.canAuthenticate: Result = $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('BiometricService.canAuthenticate error: $e');
      debugPrint('BiometricService.canAuthenticate stackTrace: $stackTrace');
      return false;
    }
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      final can = await canAuthenticate();
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

