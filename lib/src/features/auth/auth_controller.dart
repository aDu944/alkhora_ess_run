import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../core/storage/secure_kv.dart';
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
      await SecureKv.write(SecureKeys.biometricEnabled, '1');
      state = AsyncValue.data(AuthSession(user: u));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    final client = await ref.read(frappeClientProvider.future);
    await client.logout();
    await SecureKv.deleteAll();
    state = const AsyncValue.data(null);
  }
}

