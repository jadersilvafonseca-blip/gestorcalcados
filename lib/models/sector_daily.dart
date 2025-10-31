// lib/models/sector_daily.dart
class SectorDaily {
  final String sectorId; // ex: corte
  final String dateYmd; // ex: 2025-10-23
  final int pairs; // total de pares produzidos neste dia

  SectorDaily({
    required this.sectorId,
    required this.dateYmd,
    required this.pairs,
  });

  Map<String, dynamic> toMap() => {
        'sectorId': sectorId,
        'dateYmd': dateYmd,
        'pairs': pairs,
      };

  factory SectorDaily.fromMap(Map map) => SectorDaily(
        sectorId: (map['sectorId'] ?? '').toString(),
        dateYmd: (map['dateYmd'] ?? '').toString(),
        pairs: (map['pairs'] as int?) ?? 0,
      );
}
