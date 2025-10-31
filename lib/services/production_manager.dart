// lib/services/production_manager.dart
import 'package:hive/hive.dart';
import '../services/hive_service.dart';

/// Boxes auxiliares
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';

class ProductionManager {
  // CORREÇÃO: Usando a instância estática correta (instance)
  static final ProductionManager instance = ProductionManager._internal();
  factory ProductionManager() => instance;
  ProductionManager._internal();

  // --- Boxes ---
  late Box<dynamic> _movBox;
  late Box<dynamic> _dailyBox;

  /// Inicializa as boxes (passadas já abertas)
  Future<void> initHiveBoxes({
    required Box<dynamic> eventsBox,
    required Box<dynamic> countersBox,
  }) async {
    _movBox = eventsBox;
    _dailyBox = countersBox;
  }

  String _openKey(String ticketId, String sector) => 'open::$ticketId::$sector';
  String _histKey(String ticketId) => 'hist::$ticketId';
  String _prodKey(String sector, String dateYmd) => '$sector::$dateYmd';
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // -------------------- FUNÇÕES PRINCIPAIS --------------------

  Future<bool> entrada({
    required Map<String, dynamic> ticketData,
    required String sectorId,
  }) async {
    final ticketId = ticketData['id'].toString();

    // 1. Verifica se há ticket aberto em outro setor
    String? setorAberto;
    for (final k in _movBox.keys) {
      if (k is String && k.startsWith('open::$ticketId::')) {
        final parts = k.split('::');
        if (parts.length == 3) {
          setorAberto = parts[2];
          break;
        }
      }
    }
    if (setorAberto != null) return false;

    // 2. Verifica histórico
    final hk = _histKey(ticketId);
    final hist = (_movBox.get(hk) as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    final jaSaiuDesteSetor = hist
        .any((mov) => mov.containsKey('sector') && mov['sector'] == sectorId);
    if (jaSaiuDesteSetor) return false;

    // 3. Adiciona a entrada
    await _movBox.put(_openKey(ticketId, sectorId), {
      'ticketId': ticketId,
      'sector': sectorId,
      'pairs': ticketData['pairs'],
      'inAt': DateTime.now().toIso8601String(),
    });

    // 4. Garante que o ticket existe
    await _ensureTicketExists(ticketData);

    return true;
  }

  Future<bool> saida({
    required Map<String, dynamic> ticketData,
    required String sectorId,
  }) async {
    final ticketId = ticketData['id'].toString();
    final key = _openKey(ticketId, sectorId);
    final open = _movBox.get(key);
    if (open == null) return false;

    final outAt = DateTime.now();
    final movClosed = Map<String, dynamic>.from(open);
    movClosed['outAt'] = outAt.toIso8601String();

    // 1. Salva no histórico
    final hk = _histKey(ticketId);
    final hist = (_movBox.get(hk) as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    hist.add(movClosed);
    await _movBox.put(hk, hist);

    // 2. Remove o aberto
    await _movBox.delete(key);

    // 3. Atualiza produção diária
    final ymd = _ymd(outAt);
    final pk = _prodKey(sectorId, ymd);
    final current = (_dailyBox.get(pk) as int?) ?? 0;
    final produced = (open['pairs'] as int?) ?? (ticketData['pairs'] as int);
    await _dailyBox.put(pk, current + produced);

    return true;
  }

  // -------------------- AUXILIARES --------------------

  Future<void> _ensureTicketExists(Map<String, dynamic> ticketData) async {
    final all = HiveService.getAllTickets();
    final exists = all.any((e) => e.id == ticketData['id']);
    if (exists) return;

    try {
      const ticketsBoxName = 'tickets_box';
      if (Hive.isBoxOpen(ticketsBoxName)) {
        final box = Hive.box(ticketsBoxName);
        await box.put(ticketData['id'].toString(), ticketData);
      }
    } catch (_) {
      // noop
    }
  }

  List<Map<String, dynamic>> getOpenMovements(String sectorId) {
    final result = <Map<String, dynamic>>[];
    for (final k in _movBox.keys) {
      if (k is String && k.startsWith('open::')) {
        final parts = k.split('::');
        if (parts.length == 3 && parts[2] == sectorId) {
          result.add(Map<String, dynamic>.from(_movBox.get(k)));
        }
      }
    }
    return result;
  }

  int getDailyProduction(String sectorId, DateTime date) {
    final pk = _prodKey(sectorId, _ymd(date));
    return (_dailyBox.get(pk) as int?) ?? 0;
  }

  // --- CORREÇÃO DAS FUNÇÕES VAZIAS ---

  /// Soma os pares de todas as fichas abertas nesse setor
  int getFichasEmProducao(String firestoreId) {
    final openMovements = getOpenMovements(firestoreId);
    int totalPares = 0;
    for (final movement in openMovements) {
      totalPares += (movement['pairs'] as int?) ?? 0;
    }
    return totalPares;
  }

  /// Pega a produção diária para a data de "hoje"
  int getProducaoDoDia(String firestoreId) {
    // Chama a função já existente, mas com a data de "hoje"
    return getDailyProduction(firestoreId, DateTime.now());
  }

  // --- MÉTODO DE RELATÓRIO ADICIONADO CORRETAMENTE ---

  /// Gera um relatório de produção para um período e setores específicos.
  ProductionReport generateProductionReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<String>
        sectorIds, // Lista de IDs de setores (ex: 'corte', 'montagem')
    required Map<String, String>
        sectorNames, // Mapa de ID para Nome (ex: {'corte': 'Corte'})
  }) {
    // Ajusta a data final para incluir o dia inteiro (até 23:59:59)
    final endDateAdjusted =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    int grandTotalProduced = 0;
    int grandTotalInProduction = 0;
    final List<SectorReportData> allSectorData = [];

    // 1. Itera sobre cada setor que o usuário selecionou
    for (final sectorId in sectorIds) {
      int sectorProduced = 0;
      final List<Map<String, dynamic>> sectorFinalizedFichas = [];

      // 2. Calcula "PRODUZIDO NO PERÍODO" (lendo o histórico)
      // Itera sobre todas as chaves do histórico
      for (final key in _movBox.keys) {
        if (key is String && key.startsWith('hist::')) {
          final histList = _movBox.get(key) as List?;
          if (histList == null) continue;

          for (final movement in histList) {
            if (movement is Map) {
              // Verifica se o movimento é do setor correto e tem data de saída
              if (movement['sector'] == sectorId && movement['outAt'] != null) {
                try {
                  final outAtDate = DateTime.parse(movement['outAt']);

                  // Verifica se a data de saída está DENTRO do período selecionado
                  if (!outAtDate.isBefore(startDate) &&
                      outAtDate.isBefore(endDateAdjusted)) {
                    final pairs = (movement['pairs'] as int?) ?? 0;
                    sectorProduced += pairs;
                    sectorFinalizedFichas
                        .add(Map<String, dynamic>.from(movement));
                  }
                } catch (_) {
                  // Ignora se a data for inválida
                }
              }
            }
          }
        }
      }

      // 3. Calcula "EM PRODUÇÃO ATUALMENTE" (lendo as fichas abertas)
      // (Isso usa os métodos que você já tinha!)
      final sectorInProduction = getFichasEmProducao(sectorId);
      final sectorOpenFichas = getOpenMovements(sectorId);

      // 4. Adiciona os dados deste setor à lista
      allSectorData.add(
        SectorReportData(
          sectorId: sectorId,
          sectorName: sectorNames[sectorId] ?? sectorId,
          producedInRange: sectorProduced,
          finalizedFichasInRange: sectorFinalizedFichas,
          currentlyInProduction: sectorInProduction,
          openFichas: sectorOpenFichas,
        ),
      );

      grandTotalProduced += sectorProduced;
      grandTotalInProduction += sectorInProduction;
    }

    // 5. Retorna o relatório completo
    return ProductionReport(
      startDate: startDate,
      endDate: endDate,
      sectorData: allSectorData,
      totalProducedInRange: grandTotalProduced,
      totalCurrentlyInProduction: grandTotalInProduction,
    );
  }
} // <-- FIM DA CLASSE ProductionManager

// --- MODELOS PARA O RELATÓRIO ---
// (Estão FORA da classe ProductionManager, que é o correto)

/// Contém o resultado completo do relatório gerado.
class ProductionReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<SectorReportData> sectorData;

  // Totais gerais
  final int totalProducedInRange;
  final int totalCurrentlyInProduction;

  ProductionReport({
    required this.startDate,
    required this.endDate,
    required this.sectorData,
    required this.totalProducedInRange,
    required this.totalCurrentlyInProduction,
  });
}

/// Contém os dados de um setor específico.
class SectorReportData {
  final String sectorId;
  final String sectorName;

  // O que foi produzido (finalizado) no período
  final int producedInRange;
  final List<Map<String, dynamic>> finalizedFichasInRange;

  // O que está em produção (aberto) agora
  final int currentlyInProduction;
  final List<Map<String, dynamic>> openFichas;

  SectorReportData({
    required this.sectorId,
    required this.sectorName,
    required this.producedInRange,
    required this.finalizedFichasInRange,
    required this.currentlyInProduction,
    required this.openFichas,
  });
}
