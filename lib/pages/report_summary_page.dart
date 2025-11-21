import 'package:flutter/material.dart';

// --- MUDANÇA (A CAUSA DO ERRO) ---
// import 'package:gestor_calcados_new/models/product.dart'; // ANTIGO (REMOVIDO)
import 'package:gestor_calcados_new/models/ticket_model.dart'; // NOVO (CORRIGIDO)
// --- FIM DA MUDANÇA ---

import 'package:share_plus/share_plus.dart';

class ReportSummaryPage extends StatelessWidget {
  final List<String> ticketIds;
  final List<MaterialEstimate> estimates;

  const ReportSummaryPage({
    super.key,
    required this.ticketIds,
    required this.estimates,
  });

  String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

  // --- FUNÇÃO PARA GERAR O TEXTO FINAL (REMOVIDAS AS PEÇAS) ---
  String _generateShareableText() {
    final StringBuffer buffer = StringBuffer();

    // Título
    buffer.writeln('📋 *RELATÓRIO DE CONSUMO*');
    buffer.writeln('--------------------------------');

    // Fichas
    buffer.writeln('👉 *Fichas Incluídas* (${ticketIds.length}):');
    buffer.writeln(ticketIds.join(', '));
    buffer.writeln('');

    // Consumo Agregado
    buffer.writeln('📦 *CONSUMO TOTAL (Metragem)*');

    for (var e in estimates) {
      final materialDisplay =
          '${e.material} (${e.color.isNotEmpty ? e.color : 'S/Cor'})';

      // Formatação para mostrar 2 ou 3 casas decimais
      final metersDisplay = e.meters >= 1
          ? '${e.meters.toStringAsFixed(2)}m'
          : (e.meters > 0 ? '${e.meters.toStringAsFixed(3)}m' : '0.00m');

      // Linha principal do consumo (apenas Material e Metragem)
      buffer.writeln('*${materialDisplay}:* $metersDisplay');

      // *** LINHA DAS PEÇAS FOI REMOVIDA DAQUI ***
    }

    return buffer.toString();
  }

  // --- FUNÇÃO PARA COMPARTILHAR ---
  void _onShareReport(BuildContext context) async {
    final text = _generateShareableText();
    await Share.share(text);
  }
  // --- FIM DAS FUNÇÕES NOVAS ---

  @override
  Widget build(BuildContext context) {
    // Para otimizar a visualização do widget
    _generateShareableText();
    final estimatesCount = estimates.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Consumo'),
        // Adiciona o botão de compartilhar na AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () => _onShareReport(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Seção 1: Fichas incluídas
          Text(
            'Fichas Incluídas (${ticketIds.length}):',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(ticketIds.join(', ')),
          const Divider(height: 24),

          // Seção 2: Consumo Total (Título)
          Text(
            'CONSUMO TOTAL (${estimatesCount} Materiais)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Lista de Materiais
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: estimatesCount,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final e = estimates[index];
                // final piecesStr = e.pieceNames.join(', '); // Comentado/removido
                final metersDisplay = e.meters >= 1
                    ? _formatMeters(e.meters)
                    : (e.meters > 0 ? _formatMeters(e.meters) : '0.00m');

                return ListTile(
                  title: Text(
                    '${e.material} (${e.color})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Subtitle agora é SÓ a metragem (sem peças)
                  subtitle: Text(metersDisplay),

                  // O trailing é removido ou ajustado
                  // Vou remover o trailing e deixar só o subtitle como metragem,
                  // para simplificar a visualização, já que a lista é SÓ o consumo.
                  // Se preferir manter o trailing:
                  trailing: Text(
                    _formatMeters(e.meters),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  // Se preferir o subtitle apenas com a metragem, remova o trailing
                  // e remova o código do subtitle acima. Por enquanto, mantenho o trailing.
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
