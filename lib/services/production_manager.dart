import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:collection'; // Necessário para LinkedHashMap
import 'dart:convert'; // Importado para o parseQrCode
import '../models/sector_models.dart';
import '../models/report_models.dart';

// --- COLEÇÕES GLOBAIS (FILTRADAS POR TEAMID) ---
const String kTicketsCollection = 'tickets';
const String kMovementsCollection = 'movements';
const String kDailyProductionCollection = 'daily_production';
const String kActiveBottlenecksCollection = 'bottlenecks_active';
const String kHistoryBottlenecksCollection = 'bottlenecks_history';

const String kMissingPartReason = 'Reposição de peça';
const String kOtherReason = 'Outros (especificar)';
const String kTransitSectorId = 'transito';

class ProductionManager {
  static final ProductionManager instance = ProductionManager._internal();
  factory ProductionManager() => instance;
  ProductionManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, ConfigurableSector>? _sectorModelsCache;

  // -------------------- UTIL --------------------
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _prodKey(String sector, String dateYmd) => '$sector::$dateYmd';
  String getDayKey(DateTime d) => _ymd(d);

  // --- NOVOS HELPERS DE COLEÇÃO (PARA MULTI-FÁBRICA) ---
  CollectionReference _sectorsCol(String teamId) {
    return _db.collection('teams').doc(teamId).collection('sectors');
  }

  // 🟢 ADICIONADO: Helper para coleções de movimentação
  CollectionReference _movementsCol(String teamId) {
    return _db.collection('teams').doc(teamId).collection(kMovementsCollection);
  }

  DocumentReference _orderDoc(String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('config')
        .doc('sector_order');
  }
  // --- FIM DOS NOVOS HELPERS ---

  Future<T> _retry<T>(Future<T> Function() fn,
      {int retries = 3,
      Duration initialDelay = const Duration(milliseconds: 300)}) async {
    var attempt = 0;
    var delay = initialDelay;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= retries) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  // -------------------- SETORES (AGORA POR TEAMID) --------------------
  void refreshSectorCache() => _sectorModelsCache = null;

  Future<void> initFirebase() async {
    // A criação de setores agora é por time, no getAllSectorModels.
  }

  Future<void> _ensureDefaultSectorsExist(String teamId) async {
    final orderDocRef = _orderDoc(teamId);
    final sectorsCol = _sectorsCol(teamId);

    final orderDoc = await orderDocRef.get();
    if (orderDoc.exists) return;

    final List<String> defaultOrder = [];
    final WriteBatch batch = _db.batch();

    // kDefaultSectors deve ser importado ou definido em outro lugar
    // Assumindo que kDefaultSectors existe e está acessível.
    // for (final sectorData in kDefaultSectors) {
    //   final sectorModel =
    //       ConfigurableSector.fromMap(Map<String, dynamic>.from(sectorData));
    //   final sectorRef = sectorsCol.doc(sectorModel.firestoreId);
    //   batch.set(sectorRef, sectorModel.toMap());
    //   defaultOrder.add(sectorModel.firestoreId);
    // }

    batch.set(orderDocRef, {'order': defaultOrder});
    await batch.commit();
  }

  Future<List<ConfigurableSector>> getAllSectorModels(String teamId) async {
    refreshSectorCache();

    final orderDocRef = _orderDoc(teamId);
    final sectorsCol = _sectorsCol(teamId);

    final orderDoc = await orderDocRef.get();
    if (!orderDoc.exists) {
      await _ensureDefaultSectorsExist(teamId);
    }

    final sectorsSnapshot = await sectorsCol.get();
    final orderDocAfter = await orderDocRef.get();

    final Map<String, ConfigurableSector> allSectorsMap = {};
    for (final doc in sectorsSnapshot.docs) {
      try {
        // --- CORREÇÃO DE CAST ---
        final sector =
            ConfigurableSector.fromMap(doc.data() as Map<String, dynamic>);
        // --- FIM DA CORREÇÃO ---
        allSectorsMap[sector.firestoreId] = sector;
      } catch (_) {
        continue;
      }
    }

    // --- CORREÇÃO DE CAST ---
    final List<String>? savedOrder =
        ((orderDocAfter.data() as Map<String, dynamic>?)?['order'] as List?)
            ?.cast<String>();
    // --- FIM DA CORREÇÃO ---

    final List<ConfigurableSector> orderedList = [];
    if (savedOrder != null) {
      for (final id in savedOrder) {
        final sector = allSectorsMap[id];
        if (sector != null) {
          orderedList.add(sector);
          allSectorsMap.remove(id);
        }
      }
    }
    orderedList.addAll(allSectorsMap.values);

    _sectorModelsCache = LinkedHashMap.fromIterable(orderedList,
        key: (s) => s.firestoreId, value: (s) => s);
    return orderedList;
  }

  Future<void> saveSectorModel(ConfigurableSector sector, String teamId) async {
    await _sectorsCol(teamId).doc(sector.firestoreId).set(sector.toMap());
    final orderDocRef = _orderDoc(teamId);
    await orderDocRef.set({
      'order': FieldValue.arrayUnion([sector.firestoreId])
    }, SetOptions(merge: true));
    refreshSectorCache();
  }

  Future<void> deleteSectorModel(String firestoreId, String teamId) async {
    await _sectorsCol(teamId).doc(firestoreId).delete();
    final orderDocRef = _orderDoc(teamId);
    await orderDocRef.update({
      'order': FieldValue.arrayRemove([firestoreId])
    });
    refreshSectorCache();
  }

  Future<void> saveSectorOrder(List<String> orderedIds, String teamId) async {
    try {
      final orderDocRef = _orderDoc(teamId);
      await orderDocRef.set({'order': orderedIds}, SetOptions(merge: true));
      refreshSectorCache();
    } catch (e) {
      debugPrint('Erro ao salvar a ordem dos setores: $e');
      rethrow;
    }
  }

  ConfigurableSector? getSectorModelById(String sectorId) {
    if (_sectorModelsCache == null) {
      debugPrint(
          "Aviso: getSectorModelById() chamado antes do cache de setores estar pronto.");
      return null;
    }
    return _sectorModelsCache![sectorId];
  }

  Future<ConfigurableSector?> getSectorModelByIdAsync(
      String sectorId, String teamId) async {
    if (sectorId.isEmpty) return null;
    if (_sectorModelsCache == null) {
      await getAllSectorModels(teamId);
    }
    return _sectorModelsCache?[sectorId];
  }

  // -------------------- TICKET (AGORA POR TEAMID) --------------------
  Future<void> _ensureTicketExists(
      Map<String, dynamic> ticketData, String teamId) async {
    final ticketRef =
        _db.collection(kTicketsCollection).doc(ticketData['id'].toString());
    final dataToSave = ticketData..['teamId'] = teamId;
    await ticketRef.set(dataToSave, SetOptions(merge: true));
  }

  // -------------------- ENTRADA (CORRIGIDA - LINHA 263) --------------------
  Future<bool> entrada({
    required Map<String, dynamic> ticketData,
    required String sectorId,
    required String teamId,
  }) async {
    final ticketId = ticketData['id'].toString();

    // ✅ DEPOIS (CORRETO): Usa o helper _movementsCol
    final movementsCol = _movementsCol(teamId);

    try {
      await _retry(() async {
        return await _db.runTransaction((tx) async {
          // [REGRA MANTIDA] Verifica se a ficha já passou (foi fechada) neste setor
          final historyQuery = await movementsCol
              .where('teamId', isEqualTo: teamId)
              .where('ticketId', isEqualTo: ticketId)
              .where('sector', isEqualTo: sectorId)
              .where('status', isEqualTo: 'closed')
              .limit(1)
              .get();
          if (historyQuery.docs.isNotEmpty) {
            throw Exception('Ficha já passou por este setor');
          }

          // [NOVA REGRA] Verifica se a ficha já está aberta NESTE setor (evita bip duplo)
          // (Esta consulta vai exigir um novo índice no Firestore)
          final alreadyOpenQuery = await movementsCol
              .where('teamId', isEqualTo: teamId)
              .where('ticketId', isEqualTo: ticketId)
              .where('sector', isEqualTo: sectorId)
              .where('status', isEqualTo: 'open')
              .limit(1)
              .get();
          if (alreadyOpenQuery.docs.isNotEmpty) {
            throw Exception('Ficha já está aberta NESTE setor');
          }

          // Cria o novo movimento
          final newMovRef = movementsCol.doc();
          tx.set(newMovRef, {
            'teamId': teamId,
            'ticketId': ticketId,
            'sector': sectorId,
            'status': 'open',
            'pairs': ticketData['pairs'] ?? 0,
            'inAt': FieldValue.serverTimestamp(),
            'ticketData': ticketData,
          });

          // [REMOVIDO] Não atualizamos mais o 'ticket' com o
          // 'currentMovementId', pois a ficha pode estar em vários lugares.
        });
      });

      // Garante que os dados do ticket existem (ex: modelo, cor, etc.)
      await _ensureTicketExists(ticketData, teamId);
      return true;
    } catch (e) {
      debugPrint('entrada() falhou: $e');
      return false;
    }
  }

  // -------------------- SAIDA (CORRIGIDA - LINHA 328) --------------------
  Future<bool> saida({
    required Map<String, dynamic> ticketData,
    required String sectorId,
    required String teamId,
  }) async {
    final ticketId = ticketData['id'].toString();

    // ✅ DEPOIS (CORRETO): Usa o helper _movementsCol
    final movementsCol = _movementsCol(teamId);

    try {
      await _retry(() async {
        return await _db.runTransaction((tx) async {
          // Buscamos o movimento aberto específico para ESTA ficha NESTE setor
          // (Esta consulta vai exigir um novo índice no Firestore)
          final openMovementQuery = await movementsCol
              .where('teamId', isEqualTo: teamId)
              .where('ticketId', isEqualTo: ticketId)
              .where('sector', isEqualTo: sectorId)
              .where('status', isEqualTo: 'open')
              .limit(1)
              .get();

          if (openMovementQuery.docs.isEmpty) {
            throw Exception(
                'Ficha não encontrada ou não está aberta neste setor');
          }

          // Encontramos o movimento a ser fechado
          final openMovRef = openMovementQuery.docs.first.reference;
          // final openData =
          //     openMovementQuery.docs.first.data() as Map<String, dynamic>; // Não é usado

          // Fechamos o movimento
          tx.update(openMovRef, {
            'status': 'closed',
            'outAt': FieldValue.serverTimestamp(),
          });

          // [BLOCO REMOVIDO]
          // Não criamos mais um movimento de 'transito' e
          // não atualizamos mais o 'ticket'.
        });
      });

      // [LÓGICA MANTIDA] Atualiza a produção diária
      final outAt = DateTime.now();
      final ymd = _ymd(outAt);
      final pk = '$teamId::$sectorId::$ymd';

      final dailyProdRef = _db.collection(kDailyProductionCollection).doc(pk);
      await dailyProdRef.set({
        'count': FieldValue.increment(ticketData['pairs'] ?? 0),
        'sectorId': sectorId,
        'teamId': teamId,
        'date': ymd,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('saida() falhou: $e');
      return false;
    }
  }

  // -------------------- AUXILIARES (Leitura, AGORA POR TEAMID) --------------------

  Map<String, dynamic>? parseQrCode(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        final map = decoded;
        final id = (map['id'] ?? map['ticketId'] ?? '').toString();
        final modelo = (map['modelo'] ?? '').toString();
        final cor = (map['cor'] ?? '').toString();
        final marca = (map['marca'] ?? '').toString();
        final pairs =
            int.tryParse((map['pairs'] ?? map['total'] ?? '0').toString()) ?? 0;
        if (id.isNotEmpty && pairs > 0) {
          return {
            'id': id,
            'modelo': modelo,
            'cor': cor,
            'marca': marca,
            'pairs': pairs,
          };
        }
      }
    } catch (_) {}
    final parts = raw.split('|');
    if (parts.length >= 6 && parts[0].toUpperCase() == 'TK') {
      final id = parts[1].trim();
      final modelo = parts[2].trim();
      final cor = parts[3].trim();
      final marca = parts[4].trim();
      final pairs = int.tryParse(parts[5].trim()) ?? 0;
      if (id.isNotEmpty && pairs > 0) {
        return {
          'id': id,
          'modelo': modelo,
          'cor': cor,
          'marca': marca,
          'pairs': pairs,
        };
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTicketDataFromFirebase(
      String ticketId) async {
    try {
      final docSnap =
          await _db.collection(kTicketsCollection).doc(ticketId).get();
      if (docSnap.exists) {
        // --- CORREÇÃO DE CAST ---
        final data = docSnap.data() as Map<String, dynamic>;
        // --- FIM DA CORREÇÃO ---
        data['id'] ??= docSnap.id;
        data['pairs'] ??= int.tryParse((data['total'] ?? '0').toString()) ?? 0;
        data['modelo'] ??= '';
        data['cor'] ??= '';
        data['marca'] ??= '';
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Erro em getTicketDataFromFirebase: $e');
      return null;
    }
  }

  // -------------------------------------------------------------
  // === NOVO MÉTODO PARA BUSCAR O HISTÓRICO DE 7 DIAS (PARA O GRÁFICO) ===
  // -------------------------------------------------------------
  Future<Map<String, int>> getSevenDayProductionHistory(
      String sectorId, String teamId) async {
    final Map<String, int> history = LinkedHashMap();
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final ymd = _ymd(date);

      final production = await getDailyProduction(sectorId, date, teamId);
      history[ymd] = production;
    }

    return history;
  }
  // -------------------------------------------------------------
  // === FIM DO NOVO MÉTODO ===
  // -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOpenMovements(
      String sectorId, String teamId) async {
    final query = _db
        .collection(kMovementsCollection)
        .where('teamId', isEqualTo: teamId)
        .where('sector', isEqualTo: sectorId)
        .where('status', isEqualTo: 'open');
    final snapshot = await query.get();
    // --- CORREÇÃO: Sem cast desnecessário ---
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getClosedMovements(
      String sectorId, String teamId) async {
    final snapshot = await _db
        .collection(kMovementsCollection)
        .where('teamId', isEqualTo: teamId)
        .where('sector', isEqualTo: sectorId)
        .where('status', isEqualTo: 'closed')
        .get();
    // --- CORREÇÃO: Sem cast desnecessário ---
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<int> getDailyProduction(
      String sectorId, DateTime date, String teamId) async {
    final pk = '$teamId::$sectorId::${_ymd(date)}';
    final docSnap =
        await _db.collection(kDailyProductionCollection).doc(pk).get();
    if (!docSnap.exists) return 0;

    // --- CORREÇÃO DE CAST ---
    final data = docSnap.data() as Map<String, dynamic>?;
    if (data?['teamId'] != teamId) return 0;
    return (data?['count'] as int?) ?? 0;
    // --- FIM DA CORREÇÃO ---
  }

  Future<int> getFichasEmProducao(String firestoreId, String teamId) async {
    final query = _db
        .collection(kMovementsCollection)
        .where('teamId', isEqualTo: teamId)
        .where('sector', isEqualTo: firestoreId)
        .where('status', isEqualTo: 'open');

    final snapshot = await query.get();
    int sum = 0;
    for (final doc in snapshot.docs) {
      // --- CORREÇÃO DE CAST ---
      sum += (doc.data()['pairs'] as int?) ?? 0;
      // --- FIM DA CORREÇÃO ---
    }
    return sum;
  }

  Future<int> getProducaoDoDia(String firestoreId, String teamId) async {
    return getDailyProduction(firestoreId, DateTime.now(), teamId);
  }

  // -------------------- STREAMS (AGORA POR TEAMID) --------------------

  Stream<List<ConfigurableSector>> getAllSectorModelsStream(String teamId) {
    return _orderDoc(teamId).snapshots().asyncMap((_) {
      return getAllSectorModels(teamId);
    });
  }

  Stream<List<Map<String, dynamic>>> getAllActiveBottlenecksStream(
      String teamId) {
    return _db
        .collection(kActiveBottlenecksCollection)
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((d) => d.data())
            .toList()); // <-- CORREÇÃO: Sem cast
  }

  Stream<List<Map<String, dynamic>>> getAllWorkInProgressFichasStream(
      String teamId) {
    return _db
        .collection(kMovementsCollection)
        .where('teamId', isEqualTo: teamId)
        // [ALTERADO] Removemos 'transito'
        .where('status', isEqualTo: 'open')
        .orderBy('inAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((d) => d.data())
            .toList()); // <-- CORREÇÃO: Sem cast
  }

  Stream<int> getProducaoDoDiaStream(String firestoreId, String teamId) {
    if (firestoreId.isEmpty) return Stream.value(0);
    final pk = '$teamId::$firestoreId::${_ymd(DateTime.now())}';
    return _db
        .collection(kDailyProductionCollection)
        .doc(pk)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      // --- CORREÇÃO DE CAST ---
      final data = doc.data() as Map<String, dynamic>?;
      if (data?['teamId'] != teamId) return 0;
      return (data?['count'] as int?) ?? 0;
      // --- FIM DA CORREÇÃO ---
    });
  }

  Stream<int> getFichasEmProducaoStream(String firestoreId, String teamId) {
    return _db
        .collection(kMovementsCollection)
        .where('teamId', isEqualTo: teamId)
        .where('sector', isEqualTo: firestoreId)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
      int sum = 0;
      for (final doc in snapshot.docs) {
        // --- CORREÇÃO DE CAST ---
        sum += (doc.data()['pairs'] as int?) ?? 0;
        // --- FIM DA CORREÇÃO ---
      }
      return sum;
    });
  }

  // -------------------- RELATÓRIOS (AGORA POR TEAMID) --------------------
  Future<ProductionReport> generateProductionReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<String> sectorIds,
    required Map<String, String> sectorNames,
    required String teamId,
  }) async {
    final endDateAdjusted =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    int grandTotalProduced = 0;
    int grandTotalInProduction = 0;
    final List<SectorReportData> allSectorData = [];

    // 🔴 FALHA CORRIGIDA AQUI: Usando objetos DateTime para o Firestore
    final movementsSnapshot = await _movementsCol(teamId)
        .where('teamId', isEqualTo: teamId) // Redundante, mas OK
        .where('status', isEqualTo: 'closed')
        .where('outAt', isGreaterThanOrEqualTo: startDate) // 🟢 CORRIGIDO
        .where('outAt', isLessThanOrEqualTo: endDateAdjusted) // 🟢 CORRIGIDO
        .get();

    final Map<String, List<Map<String, dynamic>>> closedBySector = {};
    for (final doc in movementsSnapshot.docs) {
      // --- CORREÇÃO DE CAST ---
      final m = doc.data() as Map<String, dynamic>;
      // --- FIM DA CORREÇÃO ---
      if (m['status'] == 'closed') {
        final sid = m['sector'] ?? 'desconhecido';
        // É necessário filtrar por setor no cliente, pois não se pode combinar
        // consultas de intervalo (data) com consultas array-contains-any (setores).
        if (sectorIds.contains(sid)) {
          closedBySector.putIfAbsent(sid, () => []).add(m);
        }
      }
    }

    for (final sectorId in sectorIds) {
      int sectorProduced = 0;
      final sectorFinalizedFichas = closedBySector[sectorId] ?? [];

      for (final movement in sectorFinalizedFichas) {
        sectorProduced += (movement['pairs'] as int?) ?? 0;
      }

      final sectorInProduction = await getFichasEmProducao(sectorId, teamId);
      final sectorOpenFichas = await getOpenMovements(sectorId, teamId);

      allSectorData.add(SectorReportData(
        sectorId: sectorId,
        sectorName: sectorNames[sectorId] ?? sectorId,
        producedInRange: sectorProduced,
        finalizedFichasInRange: sectorFinalizedFichas,
        currentlyInProduction: sectorInProduction,
        openFichas: sectorOpenFichas,
      ));

      grandTotalProduced += sectorProduced;
      grandTotalInProduction += sectorInProduction;
    }

    return ProductionReport(
      startDate: startDate,
      endDate: endDate,
      sectorData: allSectorData,
      totalProducedInRange: grandTotalProduced,
      totalCurrentlyInProduction: grandTotalInProduction,
    );
  }

  // -------------------- GARGALOS (AGORA POR TEAMID) --------------------
  final List<String> kBottleneckReasons = [
    'Faltou funcionário',
    'Máquina estragada',
    'Falta de Energia',
    'Acidente de trabalho',
    kMissingPartReason,
    kOtherReason,
  ];

  Future<void> createBottleneck({
    required String sectorId,
    required String reason,
    required String teamId,
    String? customReason,
    String? partName,
  }) async {
    final key = _db.collection(kActiveBottlenecksCollection).doc().id;
    final data = {
      'id': key,
      'teamId': teamId,
      'sectorId': sectorId,
      'reason': reason,
      'customReason': customReason,
      'partName': partName,
      'startedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection(kActiveBottlenecksCollection).doc(key).set(data);
  }

  Future<void> resolveBottleneck({required String bottleneckKey}) async {
    final activeRef =
        _db.collection(kActiveBottlenecksCollection).doc(bottleneckKey);
    final historyRef =
        _db.collection(kHistoryBottlenecksCollection).doc(bottleneckKey);

    try {
      await _db.runTransaction((tx) async {
        final activeDoc = await tx.get(activeRef);
        if (!activeDoc.exists) return;
        // --- CORREÇÃO DE CAST ---
        final resolvedData = activeDoc.data() as Map<String, dynamic>;
        // --- FIM DA CORREÇÃO ---
        resolvedData['resolvedAt'] = FieldValue.serverTimestamp();
        tx.set(historyRef, resolvedData);
        tx.delete(activeRef);
      });
    } catch (e) {
      debugPrint('Erro ao resolver gargalo: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveBottlenecksForSector(
      String sectorId, String teamId) async {
    final snapshot = await _db
        .collection(kActiveBottlenecksCollection)
        .where('teamId', isEqualTo: teamId)
        .where('sectorId', isEqualTo: sectorId)
        .get();
    // --- CORREÇÃO: Sem cast desnecessário ---
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllActiveBottlenecks(
      String teamId) async {
    final snapshot = await _db
        .collection(kActiveBottlenecksCollection)
        .where('teamId', isEqualTo: teamId)
        .get();
    // --- CORREÇÃO: Sem cast desnecessário ---
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllWorkInProgressFichas(
      String teamId) async {
    final snapshot = await _db
        .collection(kMovementsCollection)
        .where('teamId', isEqualTo: teamId)
        // [ALTERADO] Removemos 'transito'
        .where('status', isEqualTo: 'open')
        .orderBy('inAt', descending: true)
        .get();
    // --- CORREÇÃO: Sem cast desnecessário ---
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<BottleneckReport> generateBottleneckReport({
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, String> sectorNames,
    required String teamId,
  }) async {
    final endDateAdjusted =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    // 🔴 FALHA CORRIGIDA AQUI: Usando objetos DateTime para o Firestore
    final snapshot = await _db
        .collection(kHistoryBottlenecksCollection)
        .where('teamId', isEqualTo: teamId)
        .where('resolvedAt', isGreaterThanOrEqualTo: startDate) // 🟢 CORRIGIDO
        .where('resolvedAt',
            isLessThanOrEqualTo: endDateAdjusted) // 🟢 CORRIGIDO
        .get();

    // --- CORREÇÃO: Sem cast desnecessário ---
    final resolvedInPeriod =
        snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    final summaryMap = <String, BottleneckSummaryItem>{};
    for (final bottleneck in resolvedInPeriod) {
      String reasonKey = bottleneck['reason'];
      if (reasonKey == kOtherReason) {
        reasonKey = bottleneck['customReason'] ?? kOtherReason;
      } else if (reasonKey == kMissingPartReason) {
        reasonKey =
            '$kMissingPartReason: ${bottleneck['partName'] ?? 'Não especificada'}';
      }
      final String sectorId = bottleneck['sectorId'] ?? 'desconhecido';
      final String sectorName = sectorNames[sectorId] ?? sectorId;
      final String compoundKey = '$sectorId::$reasonKey';
      final String displayReason = '$sectorName: $reasonKey';
      Duration duration = Duration.zero;
      try {
        final started = (bottleneck['startedAt'] as Timestamp).toDate();
        final resolved = (bottleneck['resolvedAt'] as Timestamp).toDate();
        duration = resolved.difference(started);
      } catch (e) {
        try {
          // Lógica de fallback para strings, caso o formato seja misto (legacy data)
          final started = DateTime.parse(bottleneck['startedAt']);
          final resolved = DateTime.parse(bottleneck['resolvedAt']);
          duration = resolved.difference(started);
        } catch (_) {}
      }
      if (summaryMap.containsKey(compoundKey)) {
        final item = summaryMap[compoundKey]!;
        item.count++;
        item.totalDuration += duration;
      } else {
        summaryMap[compoundKey] = BottleneckSummaryItem(
          reason: displayReason,
          count: 1,
          totalDuration: duration,
        );
      }
    }

    final summaryList = summaryMap.values.toList();
    summaryList.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

    return BottleneckReport(
      startDate: startDate,
      endDate: endDate,
      summary: summaryList,
      rawData: resolvedInPeriod,
    );
  }

  // 🟢 NOVO MÉTODO: Essencial para o detalhamento dia-a-dia na ReportPage.
  // Ele busca movimentos no período, filtrando por um campo de data ('inAt' ou 'outAt').
  Future<List<Map<String, dynamic>>> getDetailedMovementsForReport({
    required String teamId,
    required List<String> sectorIds,
    required DateTime startDate,
    required DateTime endDateAdjusted,
    required String dateField,
  }) async {
    if (sectorIds.isEmpty) return [];

    try {
      // 🟢 CORREÇÃO CRÍTICA: Passando DateTime em vez de String
      final query = _movementsCol(teamId)
          .where(dateField, isGreaterThanOrEqualTo: startDate)
          .where(dateField, isLessThanOrEqualTo: endDateAdjusted)
          .orderBy(dateField, descending: false);

      final movementsSnapshot = await query.get();

      // Filtrar setores no cliente (necessário por causa da restrição do Firestore)
      final allMovements = movementsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((data) => sectorIds.contains(data['sector']))
          .toList();

      return allMovements;
    } catch (e) {
      debugPrint(
          'Erro ao buscar movimentos detalhados (getDetailedMovementsForReport): $e');
      rethrow;
    }
  }
}
