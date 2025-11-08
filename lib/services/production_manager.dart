import 'package:hive/hive.dart';
import '../services/hive_service.dart';

/// Boxes auxiliares
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';
// --- ADICIONADO PARA GARGALOS ---
const String kBottlenecksActiveBox = 'bottlenecks_active_box';
const String kBottlenecksHistoryBox = 'bottlenecks_history_box';
// ---------------------------------

// --- ADICIONADO: Constantes de Motivo de Gargalo ---
const String kMissingPartReason =
    'Reposição de peça'; // <-- MUDANÇA: O texto foi corrigido aqui
const String kOtherReason = 'Outros (especificar)';
// ------------------------------------------------

// --- ADICIONADO: Constante para "Em Trânsito" ---
const String kTransitSectorId = 'transito';
// ---------------------------------------------

class ProductionManager {
  // CORREÇÃO: Usando a instância estática correta (instance)
  static final ProductionManager instance = ProductionManager._internal();
  factory ProductionManager() => instance;
  ProductionManager._internal();

  // --- Boxes ---
  late Box<dynamic> _movBox;
  late Box<dynamic> _dailyBox;
  // --- ADICIONADO PARA GARGALOS ---
  late Box<dynamic> _activeBottlenecksBox;
  late Box<dynamic> _historyBottlenecksBox;
  // ---------------------------------

  /// Inicializa as boxes (passadas já abertas)
  Future<void> initHiveBoxes({
    required Box<dynamic> eventsBox,
    required Box<dynamic> countersBox,
  }) async {
    _movBox = eventsBox;
    _dailyBox = countersBox;
    // --- ADICIONADO PARA GARGALOS ---
    _activeBottlenecksBox = Hive.box(kBottlenecksActiveBox);
    _historyBottlenecksBox = Hive.box(kBottlenecksHistoryBox);
    // ---------------------------------
  }

  String _openKey(String ticketId, String sector) => 'open::$ticketId::$sector';
  String _histKey(String ticketId) => 'hist::$ticketId';
  String _prodKey(String sector, String dateYmd) => '$sector::$dateYmd';
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // -------------------- FUNÇÕES PRINCIPAIS --------------------

  /// ATUALIZADO: Função de Entrada
  Future<bool> entrada({
    required Map<String, dynamic> ticketData,
    required String sectorId,
  }) async {
    final ticketId = ticketData['id'].toString();

    // 1. Verifica se há ticket aberto em outro setor
    String? setorAberto;
    dynamic openKeyAberto; // Salva a chave para apagar
    for (final k in _movBox.keys) {
      if (k is String && k.startsWith('open::$ticketId::')) {
        final parts = k.split('::');
        if (parts.length == 3) {
          setorAberto = parts[2];
          openKeyAberto = k; // Salva a chave
          break;
        }
      }
    }

    // Se estiver aberto em um setor que NÃO É "trânsito", bloqueia.
    if (setorAberto != null && setorAberto != kTransitSectorId) return false;

    // 2. Verifica histórico
    final hk = _histKey(ticketId);
    final hist = (_movBox.get(hk) as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    final jaSaiuDesteSetor = hist
        .any((mov) => mov.containsKey('sector') && mov['sector'] == sectorId);
    if (jaSaiuDesteSetor) return false;

    // 3. APAGA o status "Em Trânsito" (se existir)
    if (setorAberto == kTransitSectorId && openKeyAberto != null) {
      await _movBox.delete(openKeyAberto);
    }

    // 4. Adiciona a nova entrada
    await _movBox.put(_openKey(ticketId, sectorId), {
      'ticketId': ticketId,
      'sector': sectorId,
      'pairs': ticketData['pairs'],
      'inAt': DateTime.now().toIso8601String(),
    });

    // 5. Garante que o ticket existe
    await _ensureTicketExists(ticketData);

    return true;
  }

  /// ATUALIZADO: Função de Saída
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

    // 2. Remove o aberto E ADICIONA "EM TRÂNSITO"
    await _movBox.delete(key);

    // Cria o novo registro "Em Trânsito"
    final newTransitData = Map<String, dynamic>.from(open);
    newTransitData['sector'] =
        kTransitSectorId; // Define o setor como "trânsito"
    newTransitData['inAt'] =
        outAt.toIso8601String(); // Atualiza o InAt para o momento que saiu

    await _movBox.put(_openKey(ticketId, kTransitSectorId), newTransitData);
    // FIM DA MUDANÇA

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

  // ---------------------------------------------------
  // --- MÉTODOS DE RELATÓRIO DE PRODUÇÃO ---
  // ---------------------------------------------------

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
      for (final key in _movBox.keys) {
        if (key is String && key.startsWith('hist::')) {
          final histList = _movBox.get(key) as List?;
          if (histList == null) continue;

          for (final movement in histList) {
            if (movement is Map) {
              if (movement['sector'] == sectorId && movement['outAt'] != null) {
                try {
                  final outAtDate = DateTime.parse(movement['outAt']);
                  if (!outAtDate.isBefore(startDate) &&
                      outAtDate.isBefore(endDateAdjusted)) {
                    final pairs = (movement['pairs'] as int?) ?? 0;
                    sectorProduced += pairs;
                    sectorFinalizedFichas
                        .add(Map<String, dynamic>.from(movement));
                  }
                } catch (_) {}
              }
            }
          }
        }
      }

      // 3. Calcula "EM PRODUÇÃO ATUALMENTE"
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

  // ---------------------------------------------------
  // --- MÉTODOS DE GARGALO ---
  // ---------------------------------------------------

  /// Lista de motivos padrão para o diálogo de gargalo
  final List<String> kBottleneckReasons = [
    'Faltou funcionário',
    'Máquina estragada',
    'Falta de Energia',
    'Acidente de trabalho',
    kMissingPartReason, // <-- Esta linha agora usa a constante corrigida
    kOtherReason, // <-- Esta linha agora usa a constante corrigida
  ];

  /// Cria um novo gargalo
  Future<void> createBottleneck({
    required String sectorId,
    required String reason,
    String? customReason,
    String? partName, // <-- NOVO CAMPO
  }) async {
    final key = DateTime.now().toIso8601String();
    final data = {
      'id': key, // <-- Salva a própria chave para referência
      'sectorId': sectorId,
      'reason': reason,
      'customReason': customReason,
      'partName': partName, // <-- Salva o nome da peça
      'startedAt': key,
    };
    await _activeBottlenecksBox.put(key, data);
  }

  /// Resolve um gargalo ativo
  Future<void> resolveBottleneck({required String bottleneckKey}) async {
    final activeData = _activeBottlenecksBox.get(bottleneckKey);
    if (activeData == null) return;
    final resolvedData = Map<String, dynamic>.from(activeData);
    resolvedData['resolvedAt'] = DateTime.now().toIso8601String();
    await _historyBottlenecksBox.add(resolvedData);
    await _activeBottlenecksBox.delete(bottleneckKey);
  }

  /// Pega TODOS os gargalos ativos de um setor específico
  List<Map<String, dynamic>> getActiveBottlenecksForSector(String sectorId) {
    return _activeBottlenecksBox.values
        .where((data) => (data as Map)['sectorId'] == sectorId)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Pega TODOS os gargalos ativos (para o banner de alerta)
  List<Map<String, dynamic>> getAllActiveBottlenecks() {
    return _activeBottlenecksBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ---------------------------------------------------
  // --- NOVAS FUNÇÕES ADICIONADAS (SUGESTÕES 2 e 3) ---
  // ---------------------------------------------------

  /**
   * SUGESTÃO 3: Painel de Fichas Abertas (WIP)
   * Busca todas as fichas que estão atualmente "abertas" (open::)
   * em qualquer setor.
   */
  List<Map<String, dynamic>> getAllWorkInProgressFichas() {
    final wipFichas = <Map<String, dynamic>>[];
    for (final key in _movBox.keys) {
      if (key is String && key.startsWith('open::')) {
        wipFichas.add(Map<String, dynamic>.from(_movBox.get(key)));
      }
    }
    // Ordena pela data de entrada, as mais recentes primeiro
    wipFichas
        .sort((a, b) => (b['inAt'] as String).compareTo(a['inAt'] as String));
    return wipFichas;
  }

  /**
   * SUGESTÃO 2: Relatório de Histórico de Gargalos
   * Analisa a 'bottlenecks_history_box' e agrupa os
   * problemas por motivo e tempo total perdido.
   */
  BottleneckReport generateBottleneckReport({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // Ajusta a data final para incluir o dia inteiro (até 23:59:59)
    final endDateAdjusted =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final resolvedInPeriod = <Map<String, dynamic>>[];
    // 1. Filtra todos os gargalos resolvidos dentro do período
    for (final data in _historyBottlenecksBox.values) {
      final resolvedData = Map<String, dynamic>.from(data as Map);
      if (resolvedData['resolvedAt'] == null) continue;

      try {
        final resolvedDate = DateTime.parse(resolvedData['resolvedAt']);
        // Compara se foi resolvido dentro do range
        if (!resolvedDate.isBefore(startDate) &&
            resolvedDate.isBefore(endDateAdjusted)) {
          resolvedInPeriod.add(resolvedData);
        }
      } catch (_) {
        // Ignora datas inválidas
      }
    }

    // 2. Agrupa os gargalos filtrados por motivo
    final summaryMap = <String, BottleneckSummaryItem>{};

    for (final bottleneck in resolvedInPeriod) {
      // Define uma "chave" única para o motivo
      String reasonKey = bottleneck['reason'];
      if (reasonKey == kOtherReason) {
        reasonKey = bottleneck['customReason'] ?? kOtherReason;
      } else if (reasonKey == kMissingPartReason) {
        reasonKey =
            '$kMissingPartReason: ${bottleneck['partName'] ?? 'Não especificada'}';
      }

      // Calcula a duração do gargalo
      Duration duration = Duration.zero;
      try {
        final started = DateTime.parse(bottleneck['startedAt']);
        final resolved = DateTime.parse(bottleneck['resolvedAt']);
        duration = resolved.difference(started);
      } catch (_) {
        // Ignora se não puder calcular a duração
      }

      // Adiciona ou atualiza o item no mapa de resumo
      if (summaryMap.containsKey(reasonKey)) {
        // Se já existe, soma
        final item = summaryMap[reasonKey]!;
        item.count++;
        item.totalDuration += duration;
      } else {
        // Se é novo, cria
        summaryMap[reasonKey] = BottleneckSummaryItem(
          reason: reasonKey,
          count: 1,
          totalDuration: duration,
        );
      }
    }

    // 3. Ordena o resultado (do mais demorado para o menos)
    final summaryList = summaryMap.values.toList();
    summaryList.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

    // 4. Retorna o relatório completo
    return BottleneckReport(
      startDate: startDate,
      endDate: endDate,
      summary: summaryList,
      rawData: resolvedInPeriod, // Lista de todos os gargalos no período
    );
  }
} // <-- FIM DA CLASSE ProductionManager

// ---------------------------------------------------
// --- MODELOS DE RELATÓRIO DE PRODUÇÃO (Existentes) ---
// ---------------------------------------------------

/// Contém o resultado completo do relatório de produção.
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

// ---------------------------------------------------
// --- NOVOS MODELOS DE RELATÓRIO DE GARGALOS ---
// ---------------------------------------------------

/// Contém o resultado completo do relatório de gargalos.
class BottleneckReport {
  final DateTime startDate;
  final DateTime endDate;

  /// Uma lista resumida, agrupada por motivo.
  final List<BottleneckSummaryItem> summary;

  /// A lista completa de todos os gargalos no período.
  final List<Map<String, dynamic>> rawData;

  BottleneckReport({
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.rawData,
  });
}

/// Representa um único item no resumo do relatório de gargalos.
class BottleneckSummaryItem {
  final String reason;
  int count;
  Duration totalDuration;

  BottleneckSummaryItem({
    required this.reason,
    this.count = 0,
    this.totalDuration = Duration.zero,
  });
}
