import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class OfflineQueue {
  static const String boxName = 'offline_queue_v1';
  static const String _attendanceKey = 'attendance';

  static Box<Map> get _box => Hive.box<Map>(boxName);

  static List<Map<String, dynamic>> loadAttendance() {
    final raw = _box.get(_attendanceKey);
    if (raw == null) return [];
    final items = raw['items'];
    if (items is! List) return [];
    return items
        .whereType<String>()
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList(growable: false);
  }

  static Future<void> enqueueAttendance(Map<String, dynamic> payload) async {
    final list = loadAttendance().toList(growable: true);
    list.add(payload);
    await _box.put(
      _attendanceKey,
      <String, dynamic>{
        'items': list.map((e) => jsonEncode(e)).toList(),
      },
    );
  }

  static Future<void> replaceAttendance(List<Map<String, dynamic>> items) async {
    await _box.put(
      _attendanceKey,
      <String, dynamic>{
        'items': items.map((e) => jsonEncode(e)).toList(),
      },
    );
  }
}

