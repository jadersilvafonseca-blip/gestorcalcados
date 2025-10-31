// lib/services/fluxo_service.dart
// Versão totalmente OFFLINE — sem Firebase nem imports de Firestore.

import 'package:intl/intl.dart';

/// Serviço responsável por simular o fluxo de produção e leitura de QR Codes.
class FluxoService {
  FluxoService._();
  static final instance = FluxoService._();

  /// Faz o parse de um payload no formato "TKT|<ticketId>|PARES|<qtd>"
  Map<String, dynamic> parsePayload(String payload) {
    final p = payload.split('|');
    if (p.length < 4 || p[0] != 'TKT' || p[2] != 'PARES') {
      throw 'QR inválido.';
    }

    final id = p[1].trim();
    final pairs = int.tryParse(p[3]) ?? 0;

    if (id.isEmpty || pairs <= 0) throw 'QR inválido.';
    return {'ticketId': id, 'pairs': pairs};
  }

  /// Processa uma leitura de QR code (entrada ou saída de setor).
  /// Esta versão apenas simula as ações e registra logs no console.
  Future<void> processScan({
    required String setor,
    required String action,
    required String payload,
  }) async {
    final data = parsePayload(payload);
    final ticketId = data['ticketId'] as String;
    final pairs = data['pairs'] as int;
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final isEntrada = action == 'entrada';

    // Log simbólico do que seria enviado ao Firestore
    print('📦 [Simulação] Registro de fluxo:');
    print('  Setor: $setor');
    print('  Ticket: $ticketId');
    print('  Ação: ${isEntrada ? 'Entrada' : 'Saída'}');
    print('  Pares: $pairs');
    print('  Data: $today');

    // Simula pequena espera para UX
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// Registra gargalo ou problema do setor.
  /// Nesta versão, apenas imprime localmente.
  Future<void> addIssue({
    required String setor,
    required String tipo,
    required String descricao,
    required DateTime data,
  }) async {
    final day = DateFormat('yyyy-MM-dd').format(data);

    print('⚠️ [Simulação] Gargalo registrado:');
    print('  Setor: $setor');
    print('  Tipo: $tipo');
    print('  Descrição: $descricao');
    print('  Data: $day');

    await Future.delayed(const Duration(milliseconds: 300));
  }
}
