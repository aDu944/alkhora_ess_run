import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../core/storage/secure_kv.dart';
import '../home/attendance_controller.dart';
import 'biometric_service.dart';

class AuthSession {
  AuthSession({required this.user});
  final String user;
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final client = await ref.watch(frappeClientProvider.future);
    final lastUser = await SecureKv.read(SecureKeys.lastUser);
    final biometricEnabled = (await SecureKv.read(SecureKeys.biometricEnabled)) == '1';

    if (lastUser == null || lastUser.isEmpty) return null;

    if (biometricEnabled) {
      final ok = await BiometricService.authenticate(reason: 'Unlock');
      if (!ok) return null;
    }

    try {
      final u = await client.getLoggedUser();
      await SecureKv.write(SecureKeys.lastUser, u);
      return AuthSession(user: u);
    } catch (_) {
      return null;
    }
  }

  Future<void> login({required String usernameOrEmail, required String password}) async {
    state = const AsyncValue.loading();
    final client = await ref.read(frappeClientProvider.future);
    try {
      await client.login(usernameOrEmail: usernameOrEmail, password: password);
      final u = await client.getLoggedUser();
      await SecureKv.write(SecureKeys.lastUser, u);
      // Don't override biometric setting - it's set by user preference in login page
      // Only set it if not already set (for backward compatibility)
      final existingBiometric = await SecureKv.read(SecureKeys.biometricEnabled);
      if (existingBiometric == null) {
        // Default to enabled for backward compatibility, but user can change it
        await SecureKv.write(SecureKeys.biometricEnabled, '1');
      }
      state = AsyncValue.data(AuthSession(user: u));
      
      // Invalidate attendance controller to refresh state for new user
      ref.invalidate(attendanceControllerProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Check if this is first login (no language selected yet)
  Future<bool> isFirstLogin() async {
    final hasSelected = await SecureKv.read(SecureKeys.hasSelectedLanguage);
    return hasSelected != '1';
  }

  /// Attempt biometric login - checks if user is saved and session is still valid
  Future<void> biometricLogin() async {
    state = const AsyncValue.loading();
    final client = await ref.read(frappeClientProvider.future);
    final lastUser = await SecureKv.read(SecureKeys.lastUser);
    
    if (lastUser == null || lastUser.isEmpty) {
      state = AsyncValue.error(
        StateError('No saved user. Please login with username and password first.'),
        StackTrace.current,
      );
      return;
    }
    
    try {
      // Authenticate with biometrics
      final ok = await BiometricService.authenticate(reason: 'Login to your account');
      if (!ok) {
        state = AsyncValue.error(
          StateError('Biometric authentication failed or cancelled.'),
          StackTrace.current,
        );
        return;
      }
      
      // Verify session is still valid
      final u = await client.getLoggedUser();
      if (u == lastUser) {
        await SecureKv.write(SecureKeys.lastUser, u);
        state = AsyncValue.data(AuthSession(user: u));
        
        // Invalidate attendance controller to refresh state
        ref.invalidate(attendanceControllerProvider);
      } else {
        // Session expired or user changed
        state = AsyncValue.error(
          StateError('Session expired. Please login again.'),
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    final client = await ref.read(frappeClientProvider.future);
    await client.logout();
    await SecureKv.deleteAll();
    state = const AsyncValue.data(null);
    
    // Invalidate attendance controller to clear cached state
    ref.invalidate(attendanceControllerProvider);
  }
}

