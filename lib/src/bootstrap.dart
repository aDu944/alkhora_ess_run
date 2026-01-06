import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/offline/offline_queue.dart';
import 'core/storage/secure_kv.dart';

Future<void> bootstrap(ProviderContainer container) async {
  await Hive.initFlutter();
  await Hive.openBox<Map>(OfflineQueue.boxName);
  await SecureKv.init();
}

