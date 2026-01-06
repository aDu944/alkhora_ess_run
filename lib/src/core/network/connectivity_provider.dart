import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) async* {
  final c = Connectivity();
  await for (final results in c.onConnectivityChanged) {
    // Newer versions of connectivity_plus return List<ConnectivityResult>
    if (results is List<ConnectivityResult>) {
      if (results.isEmpty) {
        yield ConnectivityResult.none;
      } else {
        yield results.first;
      }
    } else {
      // Fallback for older versions (shouldn't happen, but handle it)
      yield ConnectivityResult.none;
    }
  }
});

final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).valueOrNull;
  // If unknown/loading, assume online to avoid flashing.
  if (status == null) return false;
  return status == ConnectivityResult.none;
});

