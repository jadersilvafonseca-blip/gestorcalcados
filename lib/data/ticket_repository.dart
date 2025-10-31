// lib/data/ticket_repository.dart
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'package:gestor_calcados_new/models/ticket.dart';

/// Converte qualquer coisa para int com segurança.
int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  final s = v.toString().trim();
  return int.tryParse(s) ?? 0;
}

class TicketRepository {
  /// Inicializa o Hive (se ainda não estiver pronto).
  Future<void> init() => HiveService.init();

  /// Retorna todos os tickets salvos no Hive.
  List<Ticket> getAll() => HiveService.getAllTickets();

  /// Cria ou atualiza um ticket no Hive.
  Future<void> upsert(Ticket t) async {
    await HiveService.addTicket(t);
  }

  /// Cria um ticket a partir de um mapa (ex.: QR) se ainda não existir.
  /// Retorna `true` se criou, `false` se já existia ou id vazio.
  Future<bool> ensureExistsFromMap(Map<String, dynamic> p) async {
    await HiveService.init(); // idempotente

    // id pode vir como 'id' ou 'ticketId'
    final id = (p['id'] ?? p['ticketId'] ?? '').toString().trim();
    if (id.isEmpty) return false;

    // Já existe?
    final exists = HiveService.getAllTickets().any((t) => t.id == id);
    if (exists) return false;

    final pairs =
        _toInt(p['pairs']) != 0 ? _toInt(p['pairs']) : _toInt(p['total']);

    final t = Ticket(
      id: id,
      cliente: (p['cliente'] ?? '').toString(),
      modelo: (p['modelo'] ?? '').toString(),
      marca: (p['marca'] ?? '').toString(),
      cor: (p['cor'] ?? '').toString(),
      pairs: pairs,
      // pode preencher a grade depois; manter vazio evita erro de tipo
      grade: const <String, int>{}, observacao: '', pedido: '',
    );

    await HiveService.addTicket(t);
    return true;
  }

  /// Constrói um `Ticket` seguro a partir de mapa (sem gravar).
  Ticket fromMap(Map<String, dynamic> p) {
    return Ticket(
      id: (p['id'] ?? p['ticketId'] ?? '').toString(),
      cliente: (p['cliente'] ?? '').toString(),
      modelo: (p['modelo'] ?? '').toString(),
      marca: (p['marca'] ?? '').toString(),
      cor: (p['cor'] ?? '').toString(),
      pairs: _toInt(p['pairs']) != 0 ? _toInt(p['pairs']) : _toInt(p['total']),
      grade: const <String, int>{},
      observacao: '',
      pedido: '',
    );
  }
}
