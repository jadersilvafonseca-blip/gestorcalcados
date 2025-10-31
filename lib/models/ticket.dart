// lib/models/ticket.dart

/// Modelo simples usado pelo HiveService e pelos repositórios.
class Ticket {
  final String id; // Nº da ficha
  final String cliente; // opcional
  final String modelo; // ex.: "REF 01"
  final String marca; // ex.: "Nike"
  final String cor; // ex.: "Branco"
  final int pairs; // total de pares
  final Map<String, int> grade; // ex.: {"34":10, "35":20, ...}
  final String observacao; // NOVO: Campo obrigatório
  final String pedido; // NOVO: Campo obrigatório

  Ticket({
    required this.id,
    required this.cliente,
    required this.modelo,
    required this.marca,
    required this.cor,
    required this.pairs,
    required this.grade,
    // INCLUÍDOS NO CONSTRUTOR:
    required this.observacao,
    required this.pedido,
  });

  factory Ticket.fromMap(Map<String, dynamic> m) {
    return Ticket(
      id: (m['id'] ?? m['ticketId'] ?? '').toString(),
      cliente: (m['cliente'] ?? '').toString(),
      modelo: (m['modelo'] ?? '').toString(),
      marca: (m['marca'] ?? '').toString(),
      cor: (m['cor'] ?? '').toString(),
      pairs: _toInt(m['pairs'] ?? m['total'] ?? 0),
      grade: Map<String, int>.from(
        (m['grade'] ?? const <String, int>{})
            .map((k, v) => MapEntry(k.toString(), _toInt(v))),
      ),
      // LÊ OS NOVOS CAMPOS DO MAP:
      observacao: (m['observacao'] ?? '').toString(),
      pedido: (m['pedido'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente': cliente,
        'modelo': modelo,
        'marca': marca,
        'cor': cor,
        'pairs': pairs,
        'grade': grade,
        // ADICIONA OS NOVOS CAMPOS NO MAP:
        'observacao': observacao,
        'pedido': pedido,
      };

  static int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString();
    return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
  }
}
