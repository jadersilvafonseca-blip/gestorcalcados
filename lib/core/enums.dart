// lib/core/enums.dart
enum SectorId {
  almoxarifado,
  corte,
  banca1,
  banca2,
  pesponto,
  montagem,
  expedicao,
}

extension SectorIdLabel on SectorId {
  String get id => name; // já bate com as chaves do Hive
  String get label {
    switch (this) {
      case SectorId.almoxarifado:
        return 'Almoxarifado';
      case SectorId.corte:
        return 'Corte';
      case SectorId.banca1:
        return 'Banca 1';
      case SectorId.banca2:
        return 'Banca 2';
      case SectorId.pesponto:
        return 'Pesponto';
      case SectorId.montagem:
        return 'Montagem';
      case SectorId.expedicao:
        return 'Expedição';
    }
  }

  static SectorId fromId(String v) {
    return SectorId.values.firstWhere(
      (e) => e.name == v,
      orElse: () => SectorId.corte,
    );
  }
}
