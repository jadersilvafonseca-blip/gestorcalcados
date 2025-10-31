// lib/models/movement.dart
class MovementOpen {
  final String ticketId;
  final String sector; // ex: corte, pesponto...
  final int pairs;
  final DateTime inAt;
  final String modelo;
  final String cor;
  final String marca;

  MovementOpen({
    required this.ticketId,
    required this.sector,
    required this.pairs,
    required this.inAt,
    this.modelo = '',
    this.cor = '',
    this.marca = '',
  });

  Map<String, dynamic> toMap() => {
        'ticketId': ticketId,
        'sector': sector,
        'pairs': pairs,
        'inAt': inAt.toIso8601String(),
        'modelo': modelo,
        'cor': cor,
        'marca': marca,
      };

  factory MovementOpen.fromMap(Map map) => MovementOpen(
        ticketId: (map['ticketId'] ?? '').toString(),
        sector: (map['sector'] ?? '').toString(),
        pairs: (map['pairs'] as int?) ?? 0,
        inAt:
            DateTime.tryParse((map['inAt'] ?? '').toString()) ?? DateTime.now(),
        modelo: (map['modelo'] ?? '').toString(),
        cor: (map['cor'] ?? '').toString(),
        marca: (map['marca'] ?? '').toString(),
      );
}

class MovementClosed extends MovementOpen {
  final DateTime outAt;

  MovementClosed({
    required super.ticketId,
    required super.sector,
    required super.pairs,
    required super.inAt,
    required this.outAt,
    super.modelo,
    super.cor,
    super.marca,
  });

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'outAt': outAt.toIso8601String(),
      };

  factory MovementClosed.fromMap(Map map) => MovementClosed(
        ticketId: (map['ticketId'] ?? '').toString(),
        sector: (map['sector'] ?? '').toString(),
        pairs: (map['pairs'] as int?) ?? 0,
        inAt:
            DateTime.tryParse((map['inAt'] ?? '').toString()) ?? DateTime.now(),
        outAt: DateTime.tryParse((map['outAt'] ?? '').toString()) ??
            DateTime.now(),
        modelo: (map['modelo'] ?? '').toString(),
        cor: (map['cor'] ?? '').toString(),
        marca: (map['marca'] ?? '').toString(),
      );
}
