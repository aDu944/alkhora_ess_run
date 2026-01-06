<<<<<<< Current (Your changes)
=======
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Offline persistence for attendance events (SQLite).
///
/// Why SQLite (vs Hive):
/// - Durable ordered queue
/// - Safer against partial writes/app crashes
/// - Easier to add conflict-resolution metadata (idempotency keys, time source, etc.)
class OfflineQueue {
  static Database? _db;

  static Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'offline_queue_v1.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE attendance_queue (
            id TEXT PRIMARY KEY,
            payload_json TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          );
        ''');
      },
    );
  }

  static Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('OfflineQueue.init() must be called before use');
    }
    return db;
  }

  static Future<int> countAttendance() async {
    final res = await _database.rawQuery('SELECT COUNT(*) as c FROM attendance_queue;');
    final first = res.isNotEmpty ? res.first : const <String, Object?>{};
    final c = first['c'];
    return (c is int) ? c : int.tryParse('$c') ?? 0;
  }

  static Future<List<Map<String, dynamic>>> loadAttendance() async {
    final rows = await _database.query(
      'attendance_queue',
      columns: const ['payload_json'],
      orderBy: 'created_at_ms ASC',
    );
    return rows
        .map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>)
        .toList(growable: false);
  }

  /// Insert a single queue item.
  ///
  /// The payload must include a stable `id` field used as the primary key.
  /// This enables idempotent retries on reconnect.
  static Future<void> enqueueAttendance(Map<String, dynamic> payload) async {
    final id = payload['id'] as String?;
    if (id == null || id.isEmpty) {
      throw ArgumentError('Offline attendance payload must contain non-empty "id"');
    }
    await _database.insert(
      'attendance_queue',
      <String, Object?>{
        'id': id,
        'payload_json': jsonEncode(payload),
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Replace the entire queue with [items] in-order.
  static Future<void> replaceAttendance(List<Map<String, dynamic>> items) async {
    await _database.transaction((txn) async {
      await txn.delete('attendance_queue');
      for (final it in items) {
        final id = it['id'] as String?;
        if (id == null || id.isEmpty) continue;
        await txn.insert(
          'attendance_queue',
          <String, Object?>{
            'id': id,
            'payload_json': jsonEncode(it),
            'created_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> deleteAttendanceByIds(Iterable<String> ids) async {
    final list = ids.where((e) => e.isNotEmpty).toList(growable: false);
    if (list.isEmpty) return;
    final placeholders = List.filled(list.length, '?').join(',');
    await _database.delete(
      'attendance_queue',
      where: 'id IN ($placeholders)',
      whereArgs: list,
    );
  }
}

>>>>>>> Incoming (Background Agent changes)
