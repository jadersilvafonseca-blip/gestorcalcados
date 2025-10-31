// lib/data/app_store.dart
import 'dart:async';
import 'package:gestor_calcados_new/models/sector_models.dart';
import 'package:gestor_calcados_new/models/ticket.dart';

class AppStore {
  AppStore._() {
    // cria streams simuladas (broadcast) só para visualização offline
    sectorsStream = _mockSectorsStream();
    ticketsStream = _mockTicketsStream();
  }

  static final AppStore instance = AppStore._();
  factory AppStore() => instance;

  // ---- Caches locais ----
  List<SectorModel> _sectorsCache = [];
  List<Ticket> _ticketsCache = [];

  // ---- Streams cacheadas (criadas uma vez) ----
  late final Stream<List<SectorModel>> sectorsStream;
  late final Stream<List<Ticket>> ticketsStream;

  // ---- Leitura do cache ----
  List<SectorModel> get sectors => _sectorsCache;
  List<Ticket> get tickets => _ticketsCache;

  int get totalHoje =>
      _sectorsCache.fold<int>(0, (acc, s) => acc + s.producaoDia);

  // ---- Inicialização (fake) ----
  Future<void> init() async {
    _sectorsCache = _mockSectorList();
    _ticketsCache = [];
  }

  // ---- Atualizações (locais) ----
  Future<void> updateSector(
    Sector sector, {
    required int emProducao,
    required int producaoDia,
  }) async {
    final idx = _sectorsCache.indexWhere((s) => s.sector == sector);
    if (idx >= 0) {
      _sectorsCache[idx] = _sectorsCache[idx].copyWith(
        emProducao: emProducao,
        producaoDia: producaoDia,
      );
    }
  }

  Future<void> addTicket(Ticket t) async {
    _ticketsCache = [..._ticketsCache, t];
  }

  Future<void> addIssue({
    required String setor,
    required String tipo,
    required String descricao,
    required DateTime data,
  }) async {
    // simulação: apenas imprime
    print("Gargalo em $setor ($tipo): $descricao");
  }

  // ---------- MOCKS PARA AMBIENTE OFFLINE ----------
  Stream<List<SectorModel>> _mockSectorsStream() {
    final lista = _mockSectorList();
    _sectorsCache = lista;
    // broadcast evita erro “Stream has already been listened to”
    return Stream<List<SectorModel>>.value(lista).asBroadcastStream();
  }

  Stream<List<Ticket>> _mockTicketsStream() {
    final lista = <Ticket>[];
    _ticketsCache = lista;
    return Stream<List<Ticket>>.value(lista).asBroadcastStream();
  }

  List<SectorModel> _mockSectorList() {
    final agora = DateTime.now();
    return Sector.values.map((s) {
      return SectorModel(
        sector: s,
        emProducao: 0,
        producaoDia: 0,
        atualizacao: agora,
      );
    }).toList();
  }

  getDailyProduction(setor) {}
}

final appStore = AppStore.instance;
