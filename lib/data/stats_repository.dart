// lib/data/stats_repository.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:gestor_calcados_new/utils/date.dart';

const String movementsBoxName = 'movements_box'; // Em produção (abertos)
const String sectorDailyBoxName = 'sector_daily'; // Produção do dia
const String sectorIssuesBoxName = 'sector_issues'; // Gargalos do dia

class StatsRepository {
  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(movementsBoxName)) await Hive.openBox(movementsBoxName);
    if (!Hive.isBoxOpen(sectorDailyBoxName))
      await Hive.openBox(sectorDailyBoxName);
    if (!Hive.isBoxOpen(sectorIssuesBoxName))
      await Hive.openBox(sectorIssuesBoxName);
  }

  // ---------------- Movements (abertos + histórico por ticket) ----------------

  Box get _mov => Hive.box(movementsBoxName);
  Box get _daily => Hive.box(sectorDailyBoxName);
  Box get _issues => Hive.box(sectorIssuesBoxName);

  String _openKey(String ticketId, String sector) => 'open::$ticketId::$sector';
  String _histKey(String ticketId) => 'hist::$ticketId';
  String _prodKey(String sector, String ymdDate) => '$sector::$ymdDate';

  /// Em qual setor a ficha está aberta (se estiver)?
  String? openedInWhichSector(String ticketId, List<String> sectors) {
    for (final s in sectors) {
      if (_mov.containsKey(_openKey(ticketId, s))) return s;
    }
    return null;
  }

  /// Registra entrada (abre movimento)
  Future<void> open(String sector, Map<String, dynamic> p) async {
    final key = _openKey(p['id'], sector);
    await _mov.put(key, {
      'ticketId': p['id'],
      'sector': sector,
      'pairs': p['pairs'],
      'inAt': DateTime.now().toIso8601String(),
      'modelo': (p['modelo'] ?? '').toString(),
      'cor': (p['cor'] ?? '').toString(),
      'marca': (p['marca'] ?? '').toString(),
    });
  }

  /// Fecha movimento, grava histórico e soma produção diária
  Future<int> close(String sector, Map<String, dynamic> p) async {
    final key = _openKey(p['id'], sector);
    final open = _mov.get(key);
    if (open == null) return 0;

    final outAt = DateTime.now();
    final movClosed = Map<String, dynamic>.from(open);
    movClosed['outAt'] = outAt.toIso8601String();

    // histórico por ticket
    final hk = _histKey(p['id']);
    final histRaw = _mov.get(hk);
    final hist = (histRaw is List)
        ? histRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    hist.add(movClosed);
    await _mov.put(hk, hist);

    // remove aberto
    await _mov.delete(key);

    // soma produção diária
    final produced = (open['pairs'] as int?) ?? (p['pairs'] as int? ?? 0);
    final dayKey = _prodKey(sector, ymd(outAt));
    final cur = (_daily.get(dayKey) as int?) ?? 0;
    await _daily.put(dayKey, cur + produced);
    return produced;
  }

  /// Lista entradas abertas no setor
  List<Map<String, dynamic>> openItems(String sector) {
    final out = <Map<String, dynamic>>[];
    for (final k in _mov.keys) {
      if (k is String && k.startsWith('open::') && k.endsWith('::$sector')) {
        final m = _mov.get(k);
        if (m is Map) out.add(Map<String, dynamic>.from(m));
      }
    }
    out.sort((a, b) =>
        (a['inAt'] ?? '').toString().compareTo((b['inAt'] ?? '').toString()));
    return out;
  }

  /// Soma de pares em produção (abertos) no setor
  int openPairsSum(String sector) {
    int total = 0;
    for (final k in _mov.keys) {
      if (k is String && k.startsWith('open::') && k.endsWith('::$sector')) {
        final m = _mov.get(k);
        if (m is Map) total += (m['pairs'] as int?) ?? 0;
      }
    }
    return total;
  }

  /// Quantidade de fichas abertas no setor
  int openCount(String sector) {
    int count = 0;
    for (final k in _mov.keys) {
      if (k is String && k.startsWith('open::') && k.endsWith('::$sector')) {
        count++;
      }
    }
    return count;
  }

  /// Produção do dia (pares finalizados hoje) por setor
  int productionToday(String sector, {DateTime? day}) {
    final now = day ?? DateTime.now();
    final key = _prodKey(sector, ymd(now));
    return (_daily.get(key) as int?) ?? 0;
  }

  // ---------------- Gargalos (issues) ----------------

  String _issuesKey(String sector, String ymdDate) =>
      'issues::$sector::$ymdDate';

  Future<void> addIssue({
    required String sector,
    required String message,
    DateTime? when,
  }) async {
    final t = when ?? DateTime.now();
    final key = _issuesKey(sector, ymd(t));
    final list =
        (_issues.get(key) as List?)?.toList() ?? <Map<String, dynamic>>[];
    list.add({'time': t.toIso8601String(), 'message': message});
    await _issues.put(key, list);
  }

  List<Map<String, dynamic>> issuesOfDay(String sector, {DateTime? day}) {
    final d = day ?? DateTime.now();
    final key = _issuesKey(sector, ymd(d));
    final raw = (_issues.get(key) as List?) ?? const [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
        .reversed
        .toList();
  }
}
