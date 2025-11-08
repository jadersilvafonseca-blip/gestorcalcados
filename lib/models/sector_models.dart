import 'package:flutter/material.dart';

// O ID do setor "Em Trânsito" precisa ser público para ser usado no dashboard
const String kTransitSectorId = 'transito';

/// ORDEM OFICIAL (controla a ordem do grid):
/// almoxarifado, corte, pesponto, banca 1, banca 2, montagem, expedição
enum Sector {
  almoxarifado,
  corte,
  pesponto,
  banca1,
  banca2,
  montagem,
  expedicao,
}

/// IDs exatos no Firestore (atenção aos espaços e acentos)
const Map<Sector, String> _fsIdBySector = {
  Sector.almoxarifado: 'almoxarifado',
  Sector.corte: 'corte',
  Sector.pesponto: 'pesponto',
  Sector.banca1: 'banca 1',
  Sector.banca2: 'banca 2',
  Sector.montagem: 'montagem',
  Sector.expedicao: 'expedicao', // sem acento no ID
};

final Map<String, Sector> _sectorByFsId = {
  for (final e in _fsIdBySector.entries) e.value: e.key
};

/// Converte o ID do Firestore -> enum
Sector? sectorFromFirestoreId(String id) => _sectorByFsId[id];

/// UI helpers
extension SectorUi on Sector {
  /// ID do documento no Firestore
  String get firestoreId => _fsIdBySector[this]!;

  String get label {
    switch (this) {
      case Sector.almoxarifado:
        return 'Estoque';
      case Sector.corte:
        return 'Corte';
      case Sector.pesponto:
        return 'Pesponto';
      case Sector.banca1:
        return 'Banca 1';
      case Sector.banca2:
        return 'Banca 2';
      case Sector.montagem:
        return 'Montagem';
      case Sector.expedicao:
        return 'Expedição';
    }
  }

  IconData get icon {
    switch (this) {
      case Sector.almoxarifado:
        return Icons.inventory_2_outlined;
      case Sector.corte:
        return Icons.content_cut;
      case Sector.pesponto:
        return Icons.straighten_outlined; // “costura”
      case Sector.banca1:
      case Sector.banca2:
        return Icons.straighten_outlined; // “costura” (Já estava assim)
      case Sector.montagem:
        return Icons.layers_outlined; // “camadas/sola”
      case Sector.expedicao:
        return Icons.local_shipping_outlined;
    }
  }

  // --- ALTERADO: Cores mais escuras e confortáveis ---
  Color get color {
    switch (this) {
      case Sector.almoxarifado:
        return const Color(0xFF2C3E50); // Azul Marinho
      case Sector.corte:
        return const Color(0xFFB84A00); // Laranja Queimado
      case Sector.pesponto:
        return const Color(0xFF00695C); // Verde Petróleo
      case Sector.banca1:
        return const Color(0xFF2E7D32); // Verde Escuro
      case Sector.banca2:
        return const Color(0xFF1B5E20); // Verde Mais Escuro
      case Sector.montagem:
        return const Color(0xFF4A148C); // Roxo Escuro
      case Sector.expedicao:
        return const Color(0xFFB71C1C); // Vermelho Escuro
    }
  }
  // --- FIM DA ALTERAÇÃO ---
}

/// Dado simplificado para exibição (se precisar)
class SectorData {
  final Sector sector;
  final int emProducao; // pares atualmente no setor
  final int producaoDia; // pares produzidos hoje (saídas)
  final DateTime atualizacao;

  const SectorData({
    required this.sector,
    required this.emProducao,
    required this.producaoDia,
    required this.atualizacao,
  });

  String? get label => null;

  SectorData copyWith({
    Sector? sector,
    int? emProducao,
    int? producaoDia,
    DateTime? atualizacao,
  }) {
    return SectorData(
      sector: sector ?? this.sector,
      emProducao: emProducao ?? this.emProducao,
      producaoDia: producaoDia ?? this.producaoDia,
      atualizacao: atualizacao ?? this.atualizacao,
    );
  }
}

/// Modelo persistível (Firestore/Hive)
class SectorModel {
  final Sector sector;
  final int emProducao;
  final int producaoDia;
  final DateTime atualizacao;

  const SectorModel({
    required this.sector,
    required this.emProducao,
    required this.producaoDia,
    required this.atualizacao,
  });

  SectorModel copyWith({
    Sector? sector,
    int? emProducao,
    int? producaoDia,
    DateTime? atualizacao,
  }) {
    return SectorModel(
      sector: sector ?? this.sector,
      emProducao: emProducao ?? this.emProducao,
      producaoDia: producaoDia ?? this.producaoDia,
      atualizacao: atualizacao ?? this.atualizacao,
    );
  }

  /// Serializa para Map (inclui sectorId p/ Firestore e sector p/ compatibilidade)
  Map<String, dynamic> toMap() {
    return {
      'sectorId': sector.firestoreId, // p/ Firestore
      'sector': sector.name, // compatibilidade
      'emProducao': emProducao,
      'producaoDia': producaoDia,
      'atualizacao': atualizacao.toIso8601String(),
    };
  }

  /// Desserializa de Map (aceita sectorId, sector, DateTime/String/int epoch)
  factory SectorModel.fromMap(Map<String, dynamic> map) {
    // tenta primeiro pelo sectorId (id do doc do Firestore)
    final sectorId = (map['sectorId'] ?? '').toString();
    Sector? s;
    if (sectorId.isNotEmpty) {
      s = sectorFromFirestoreId(sectorId);
    }
    // fallback: tentar pelo nome do enum salvo em 'sector'
    s ??= _sectorFromString((map['sector'] ?? '').toString());
    s ??= Sector.montagem; // fallback final seguro

    final emProd = (map['emProducao'] as num?)?.toInt() ?? 0;
    final prodDia = (map['producaoDia'] as num?)?.toInt() ?? 0;

    final updated = _toDate(map['atualizacao']) ?? DateTime.now();

    return SectorModel(
      sector: s,
      emProducao: emProd,
      producaoDia: prodDia,
      atualizacao: updated,
    );
  }
}

/// Helper: string -> enum (compara por name)
Sector? _sectorFromString(String v) {
  final lower = v.toLowerCase();
  for (final s in Sector.values) {
    if (s.name.toLowerCase() == lower) return s;
  }
  return null;
}

/// Converte dynamic para DateTime sem depender de Timestamp (Firestore)
DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) {
    // tenta interpretar como epoch milliseconds
    try {
      return DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {
      return null;
    }
  }
  return null;
}
