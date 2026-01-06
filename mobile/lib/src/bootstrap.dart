<<<<<<< Current (Your changes)
=======
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/secure_kv.dart';
import 'core/offline/offline_queue.dart';

Future<void> bootstrap(ProviderContainer container) async {
  await OfflineQueue.init();
  await SecureKv.init();
}

>>>>>>> Incoming (Background Agent changes)
