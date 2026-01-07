import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'time_sync_service.dart';

final timeSyncServiceProvider = FutureProvider<TimeSyncService>((ref) async {
  return TimeSyncService.create();
});


