import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_kv.dart';
import 'frappe_client.dart';

final frappeClientProvider = FutureProvider<FrappeClient>((ref) async {
  final baseUrl = await SecureKv.read(SecureKeys.baseUrl);
  return FrappeClient.create(baseUrl: baseUrl);
});

