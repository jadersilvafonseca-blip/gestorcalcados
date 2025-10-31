import 'dart:convert';

class QrTicket {
  final String id;
  final String modelo;
  final String cor;
  final String marca;
  final int pairs;

  QrTicket({
    required this.id,
    required this.modelo,
    required this.cor,
    required this.marca,
    required this.pairs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'modelo': modelo,
        'cor': cor,
        'marca': marca,
        'pairs': pairs,
      };
}

/// Aceita:
/// 1) JSON: {"id":"...", "modelo":"...", "cor":"...", "marca":"...", "pairs":120}
/// 2) Pipe: TK|<id>|<modelo>|<cor>|<marca>|<total>
QrTicket? parseQr(String raw) {
  // tenta JSON
  try {
    final map = _asJson(raw);
    final id = (map['id'] ?? map['ticketId'] ?? '').toString();
    final modelo = (map['modelo'] ?? '').toString();
    final cor = (map['cor'] ?? '').toString();
    final marca = (map['marca'] ?? '').toString();
    final pairs =
        int.tryParse((map['pairs'] ?? map['total'] ?? '0').toString()) ?? 0;
    if (id.isNotEmpty && pairs > 0) {
      return QrTicket(
          id: id, modelo: modelo, cor: cor, marca: marca, pairs: pairs);
    }
  } catch (_) {
    // segue para pipe
  }

  // pipe
  final parts = raw.split('|');
  if (parts.length >= 6 && parts[0].toUpperCase() == 'TK') {
    final id = parts[1].trim();
    final modelo = parts[2].trim();
    final cor = parts[3].trim();
    final marca = parts[4].trim();
    final pairs = int.tryParse(parts[5].trim()) ?? 0;
    if (id.isNotEmpty && pairs > 0) {
      return QrTicket(
          id: id, modelo: modelo, cor: cor, marca: marca, pairs: pairs);
    }
  }
  return null;
}

Map<String, dynamic> _asJson(String raw) {
  // pequena otimização: evita throw se claramente não é JSON
  if (!(raw.startsWith('{') && raw.endsWith('}')))
    throw const FormatException('not json');
  return Map<String, dynamic>.from(
    (jsonDecode(raw) as Map),
  );
}
