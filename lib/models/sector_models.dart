import 'package:flutter/material.dart';

// Este arquivo será o novo modelo de setor dinâmico persistível.

// O ID do setor "Em Trânsito" precisa ser público para ser usado no dashboard
const String kTransitSectorId = 'transito';

/// IDs padronizados de fábrica para a migração e fallback.
/// Esses IDs serão usados como chaves únicas (firestoreId).
const List<Map<String, dynamic>> kDefaultSectors = [
  {
    'firestoreId': 'almoxarifado',
    'label': 'Estoque',
    'iconCodePoint': 0xe41b, // Icons.inventory_2_outlined.codePoint
    'colorValue': 0xFF2C3E50,
  },
  {
    'firestoreId': 'corte',
    'label': 'Corte',
    'iconCodePoint': 0xe158, // Icons.content_cut.codePoint
    'colorValue': 0xFFB84A00,
  },
  {
    'firestoreId': 'pesponto',
    'label': 'Pesponto',
    'iconCodePoint': 0xeb91, // Icons.straighten_outlined.codePoint
    'colorValue': 0xFF00695C,
  },
  {
    'firestoreId': 'banca_1',
    'label': 'Banca 1',
    'iconCodePoint': 0xeb91,
    'colorValue': 0xFF2E7D32,
  },
  {
    'firestoreId': 'banca_2',
    'label': 'Banca 2',
    'iconCodePoint': 0xeb91,
    'colorValue': 0xFF1B5E20,
  },
  {
    'firestoreId': 'montagem',
    'label': 'Montagem',
    'iconCodePoint': 0xe3a1, // Icons.layers_outlined.codePoint
    'colorValue': 0xFF4A148C,
  },
  {
    'firestoreId': 'expedicao',
    'label': 'Expedição',
    'iconCodePoint': 0xf028c, // Corrigido: número válido para codePoint
    'colorValue': 0xFFB71C1C,
  },
];

/// Modelo configurável de setor persistido no Hive.
class ConfigurableSector {
  final String firestoreId;
  final String label;
  final int iconCodePoint;
  final int colorValue;

  const ConfigurableSector({
    required this.firestoreId,
    required this.label,
    required this.iconCodePoint,
    required this.colorValue,
  });

  // --- Helpers de UI ---
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  // --- Serialização ---
  Map<String, dynamic> toMap() => {
        'firestoreId': firestoreId,
        'label': label,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
      };

  factory ConfigurableSector.fromMap(Map<String, dynamic> map) {
    return ConfigurableSector(
      firestoreId: map['firestoreId'] as String? ?? 'unknown',
      label: map['label'] as String? ?? 'Setor Desconhecido',
      iconCodePoint: map['iconCodePoint'] as int? ?? 0xe3a1,
      colorValue: map['colorValue'] as int? ?? 0xFF4A148C,
    );
  }

  ConfigurableSector copyWith({
    String? label,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return ConfigurableSector(
      firestoreId: firestoreId,
      label: label ?? this.label,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
