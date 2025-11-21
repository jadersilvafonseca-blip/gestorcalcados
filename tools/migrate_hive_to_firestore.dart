// tools/migrate_hive_to_firestore.dart
// Rode: dart run tools/migrate_hive_to_firestore.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

Future<void> main() async {
  print('Inicializando Hive e Firestore migration tool...');
  await Hive.initFlutter();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  // Mude os nomes das boxes se forem diferentes
  const movBoxName = 'movements_box';
  const histKeyPrefix = 'hist::';
  const openKeyPrefix = 'open::';
  const ticketsBoxName = 'tickets_box';
  const dailyBoxName = 'sector_daily';
  const activeBottlenecksBox = 'bottlenecks_active_box';
  const historyBottlenecksBox = 'bottlenecks_history_box';
  const sectorsConfigBox = 'sectors_config_box';

  // Abre boxes (assume já existem localmente)
  if (!Hive.isBoxOpen(movBoxName)) await Hive.openBox(movBoxName);
  if (!Hive.isBoxOpen(ticketsBoxName)) await Hive.openBox(ticketsBoxName);
  if (!Hive.isBoxOpen(dailyBoxName)) await Hive.openBox(dailyBoxName);
  if (!Hive.isBoxOpen(activeBottlenecksBox))
    await Hive.openBox(activeBottlenecksBox);
  if (!Hive.isBoxOpen(historyBottlenecksBox))
    await Hive.openBox(historyBottlenecksBox);
  if (!Hive.isBoxOpen(sectorsConfigBox)) await Hive.openBox(sectorsConfigBox);

  final movBox = Hive.box(movBoxName);
  final ticketsBox = Hive.box(ticketsBoxName);
  final dailyBox = Hive.box(dailyBoxName);
  final activeBottlenecks = Hive.box(activeBottlenecksBox);
  final historyBottlenecks = Hive.box(historyBottlenecksBox);
  final sectorsBox = Hive.box(sectorsConfigBox);

  // 1) Migrar tickets
  print('Migrando tickets...');
  final ticketBatch = db.batch();
  int ops = 0;
  for (final key in ticketsBox.keys) {
    final raw = ticketsBox.get(key);
    if (raw == null) continue;
    final id = key.toString();
    final ref = db.collection('tickets').doc(id);
    // idempotência: escreve merge e marca migrated:true
    ticketBatch.set(
        ref,
        {...Map<String, dynamic>.from(raw as Map), '_migrated': true},
        SetOptions(merge: true));
    ops++;
    if (ops >= 400) {
      await ticketBatch.commit();
      ops = 0;
    }
  }
  if (ops > 0) await ticketBatch.commit();
  print('Tickets migrados.');

  // 2) Migrar movimentos (open::... e hist::...)
  print('Migrando movimentos (open/hist) ...');
  // open keys -> new documents in 'movements'
  final movementsCol = db.collection('movements');
  var writeBatch = db.batch();
  ops = 0;

  for (final key in movBox.keys) {
    if (key is String && key.startsWith(openKeyPrefix)) {
      try {
        final raw = movBox.get(key);
        final parts = key.split('::');
        // key format: open::<ticketId>::<sector>
        final ticketId = parts.length >= 2 ? parts[1] : null;
        final docId = '${ticketId}_${DateTime.now().microsecondsSinceEpoch}';
        final data = Map<String, dynamic>.from(raw as Map);
        data['ticketId'] ??= ticketId;
        data['_migrated'] = true;
        writeBatch.set(movementsCol.doc(docId), data);
        ops++;
        if (ops >= 450) {
          await writeBatch.commit();
          writeBatch = db.batch();
          ops = 0;
        }
      } catch (e) {
        print('Erro migrando open key $key: $e');
      }
    } else if (key is String && key.startsWith(histKeyPrefix)) {
      final histList = movBox.get(key) as List?;
      if (histList == null) continue;
      for (final raw in histList) {
        try {
          final data = Map<String, dynamic>.from(raw as Map);
          data['_migrated'] = true;
          final docId =
              '${(key as String).replaceFirst(histKeyPrefix, '')}_${DateTime.now().microsecondsSinceEpoch}';
          writeBatch.set(movementsCol.doc(docId), data);
          ops++;
          if (ops >= 450) {
            await writeBatch.commit();
            writeBatch = db.batch();
            ops = 0;
          }
        } catch (e) {
          print('Erro migrando hist entry: $e');
        }
      }
    }
  }
  if (ops > 0) await writeBatch.commit();
  print('Movimentos migrados.');

  // 3) Migrar daily counters
  print('Migrando produção diária...');
  final dailyCol = db.collection('daily_production');
  writeBatch = db.batch();
  ops = 0;
  for (final key in dailyBox.keys) {
    final val = dailyBox.get(key);
    if (val == null) continue;
    final parts = key.toString().split('::');
    if (parts.length != 2) continue;
    final sector = parts[0];
    final dateYmd = parts[1];
    final pk = '$sector::$dateYmd';
    final data = {
      'count': val is int ? val : int.tryParse(val.toString()) ?? 0,
      'sectorId': sector,
      'date': dateYmd,
      '_migrated': true,
    };
    writeBatch.set(dailyCol.doc(pk), data, SetOptions(merge: true));
    ops++;
    if (ops >= 450) {
      await writeBatch.commit();
      writeBatch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await writeBatch.commit();
  print('Produção diária migrada.');

  // 4) Gargalos ativos / historico
  print('Migrando gargalos ativos e histórico...');
  final activeCol = db.collection('bottlenecks_active');
  final historyCol = db.collection('bottlenecks_history');
  writeBatch = db.batch();
  ops = 0;
  for (final val in activeBottlenecks.values) {
    try {
      final data = Map<String, dynamic>.from(val as Map);
      final docId = data['id']?.toString() ?? activeCol.doc().id;
      data['_migrated'] = true;
      writeBatch.set(activeCol.doc(docId), data);
      ops++;
      if (ops >= 450) {
        await writeBatch.commit();
        writeBatch = db.batch();
        ops = 0;
      }
    } catch (e) {
      print('Erro migrando active bottleneck: $e');
    }
  }
  for (final val in historyBottlenecks.values) {
    try {
      final data = Map<String, dynamic>.from(val as Map);
      final docId = data['id']?.toString() ?? historyCol.doc().id;
      data['_migrated'] = true;
      writeBatch.set(historyCol.doc(docId), data);
      ops++;
      if (ops >= 450) {
        await writeBatch.commit();
        writeBatch = db.batch();
        ops = 0;
      }
    } catch (e) {
      print('Erro migrando history bottleneck: $e');
    }
  }
  if (ops > 0) await writeBatch.commit();
  print('Gargalos migrados.');

  // 5) Setores (config)
  print('Migrando configuração de setores...');
  final sectorsCol = db.collection('sectors');
  final orderDoc = db.collection('config').doc('sector_display_order');
  final Map<String, dynamic> orderDocData = {};
  List<String> orderList = [];
  for (final key in sectorsBox.keys) {
    if (key == 'sector_display_order') continue;
    final raw = sectorsBox.get(key);
    if (raw == null) continue;
    final id = key.toString();
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      data['_migrated'] = true;
      await sectorsCol.doc(id).set(data, SetOptions(merge: true));
    } catch (_) {}
  }
  final od = sectorsBox.get('sector_display_order') as List?;
  if (od != null) orderList = od.cast<String>();
  await orderDoc.set({'order': orderList}, SetOptions(merge: true));
  print('Setores migrados.');

  print('Migração concluída. Verifique no console Firestore se tudo está ok.');
  exit(0);
}
