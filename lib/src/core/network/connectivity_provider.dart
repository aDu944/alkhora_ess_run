import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) {
  final c = Connectivity();
  return c.onConnectivityChanged;
});

final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).valueOrNull;
  // If unknown/loading, assume online to avoid flashing.
  if (status == null) return false;
  return status == ConnectivityResult.none;
});

