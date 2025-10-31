// lib/services/hive_service.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:gestor_calcados_new/models/ticket.dart';

class HiveService {
  static const String _boxName = 'tickets_box';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized && Hive.isBoxOpen(_boxName)) return;
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _initialized = true;
    debugPrint('[HiveService] ok');
  }

  static bool get isReady => _initialized && Hive.isBoxOpen(_boxName);
  static Box? get _box => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;

  static ValueListenable<Box>? listenable() => _box?.listenable();

  static List<Ticket> getAllTickets() {
    final b = _box;
    if (b == null) return [];
    return b.values
        .map((e) {
          if (e is Ticket) return e;
          if (e is Map) return Ticket.fromMap(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<Ticket>()
        .toList();
  }

  static Future<void> addTicket(Ticket t) async {
    await init();
    final b = _box;
    if (b == null) return;
    final idx = _indexOfId(t.id, b);
    final data = t.toMap();
    if (idx >= 0) {
      await b.putAt(idx, data);
    } else {
      await b.add(data);
    }
  }

  static Future<void> deleteById(String id) async {
    final b = _box;
    if (b == null) return;
    final idx = _indexOfId(id, b);
    if (idx >= 0) await b.deleteAt(idx);
  }

  static Future<void> clearAll() async {
    final b = _box;
    if (b == null) return;
    await b.clear();
  }

  static int _indexOfId(String id, Box box) {
    final list = box.values.toList();
    for (int i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is Ticket && e.id == id) return i;
      if (e is Map && (e['id'] ?? '').toString() == id) return i;
    }
    return -1;
  }
}
