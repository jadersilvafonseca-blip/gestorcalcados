// lib/controllers/sector_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// IMPORT NECESSÁRIO PARA ConfigurableSector (Ajuste o caminho se for diferente)
import '../models/sector_models.dart';

/// Controller para gerenciar a lista de setores na UI.
/// Use Provider/ChangeNotifierProvider para expor este controller à UI.
class SectorController extends ChangeNotifier {
  /// Lista interna de setores
  final List<ConfigurableSector> _sectors = [];

  /// Função opcional que será chamada para persistir as mudanças.
  final Future<void> Function(List<ConfigurableSector>)? persistFn;

  // CORREÇÃO: Removendo a linha tracejada e ajustando o construtor
  SectorController({this.persistFn});

  /// --- Leitura ---
  List<ConfigurableSector> get sectors => List.unmodifiable(_sectors);

  int get count => _sectors.length;

  ConfigurableSector? getByName(String id) {
    try {
      // Usando firestoreId como o identificador único
      return _sectors.firstWhere((s) => s.firestoreId == id);
    } catch (_) {
      return null;
    }
  }

  /// Carrega uma lista (por exemplo vindo do AppStore / Hive / API)
  /// Substitui totalmente a lista atual.
  Future<void> loadFromList(List<ConfigurableSector> list,
      {bool persist = false}) async {
    _sectors.clear();
    _sectors.addAll(list);
    notifyListeners();
    if (persist && persistFn != null) {
      await persistFn!(_sectors);
    }
  }

  /// Adiciona um setor (não adiciona duplicado com mesmo ID)
  Future<bool> addSector(ConfigurableSector sector,
      {bool persist = true}) async {
    final exists = _sectors.any((s) => s.firestoreId == sector.firestoreId);
    if (exists) return false;
    _sectors.add(sector);
    notifyListeners();
    if (persist && persistFn != null) {
      await persistFn!(_sectors);
    }
    return true;
  }

  /// Remove setor por ID
  Future<bool> removeSectorByName(String id, {bool persist = true}) async {
    final initialLength = _sectors.length;
    _sectors.removeWhere((s) => s.firestoreId == id);
    final removed = _sectors.length < initialLength;
    if (removed) {
      notifyListeners();
      if (persist && persistFn != null) {
        await persistFn!(_sectors);
      }
    }
    return removed;
  }

  // ATENÇÃO: As funções updateProduction e changeProductionDeltas foram removidas
  // pois requerem campos (emProducao, producaoDia) que não existem no ConfigurableSector.
  // Se você precisar delas, adicione os campos ao seu ConfigurableSector.

  /// Ordena setores (por nome ou por outro criterio)
  void sortByName({bool ascending = true}) {
    // Ordenando pelo label (nome)
    _sectors.sort((a, b) =>
        ascending ? a.label.compareTo(b.label) : b.label.compareTo(a.label));
    notifyListeners();
  }

  /// Convert to simple Map list (útil para persistência)
  List<Map<String, dynamic>> toMapList() {
    // Usando o toMap nativo da classe ConfigurableSector
    return _sectors.map((s) => s.toMap()).toList();
  }

  /// Cria controller a partir de uma lista de maps (útil ao carregar do Hive)
  Future<void> loadFromMapList(List<Map<String, dynamic>> maps,
      {bool persist = false}) async {
    final list = maps.map((m) {
      // Usando o fromMap nativo da classe ConfigurableSector
      return ConfigurableSector.fromMap(m);
    }).toList();
    await loadFromList(list, persist: persist);
  }

  /// Limpa tudo
  Future<void> clear({bool persist = true}) async {
    _sectors.clear();
    notifyListeners();
    if (persist && persistFn != null) await persistFn!(_sectors);
  }
}
