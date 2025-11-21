import 'package:flutter/material.dart';

// Modelos
import 'package:gestor_calcados_new/models/ticket_model.dart';

// --- MUDANÇA: Importa o serviço de PDF ---
import 'package:gestor_calcados_new/services/pdf_service.dart';
// --- FIM DA MUDANÇA ---

class TicketDetailsPage extends StatelessWidget {
  final TicketModel ticket;

  const TicketDetailsPage({
    super.key,
    required this.ticket,
  });

  String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

  // ============================================================
  // --- SEÇÃO CORRIGIDA ---
  // ============================================================
  Future<void> _generatePdf(BuildContext context) async {
    // Mostra um snackbar simples de "gerando"
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando PDF...')),
    );

    try {
      // --- CORREÇÃO AQUI ---
      // Chamamos a função que gera o PDF para UMA ÚNICA ficha,
      // passando a 'ticket' que esta página já tem.
      final result = await PdfService.generateAndShareTicket(ticket);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'PDF Gerado.'),
          backgroundColor: result.ok ? Colors.green : Colors.blue,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // ============================================================
  // --- FIM DA CORREÇÃO ---
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalhes da Ficha ${ticket.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              title: 'Modelo/Cor',
              content: '${ticket.productName} / ${ticket.productColor}',
            ),
            _buildInfoCard(
              title: 'Cliente/Pedido',
              content:
                  '${ticket.cliente.isNotEmpty ? ticket.cliente : '-'} / ${ticket.pedido.isNotEmpty ? ticket.pedido : '-'}',
            ),
            _buildInfoCard(
              title: 'Total de Pares',
              content: '${ticket.pairs} Pares',
            ),
            _buildInfoCard(
              title: 'Status Atual',
              content:
                  '${ticket.currentSectorName.isNotEmpty ? ticket.currentSectorName : '-'}',
            ),
            if (ticket.observacao.isNotEmpty)
              _buildInfoCard(
                title: 'Observações',
                content: ticket.observacao,
              ),
            const SizedBox(height: 16),
            Text('GRADE DE PRODUÇÃO',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildGradeTable(ticket.grade),
            if (ticket.materialsUsed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('CONSUMO DE MATERIAIS',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildConsumptionList(ticket.materialsUsed),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _generatePdf(context),
        tooltip: 'Gerar PDF',
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }

  // (Mantenha _buildInfoCard e _buildGradeTable inalterados)
  Widget _buildInfoCard({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGradeTable(Map<String, int>? grade) {
    final safeGrade = grade ?? <String, int>{};
    final visibleEntries =
        safeGrade.entries.where((e) => (e.value) > 0).toList();

    if (visibleEntries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Nenhuma grade registrada.',
            style: TextStyle(color: Colors.grey.shade700)),
      );
    }

    visibleEntries.sort((a, b) {
      final ak = a.key;
      final bk = b.key;
      final aNum = int.tryParse(ak);
      final bNum = int.tryParse(bk);
      if (aNum != null && bNum != null) return aNum.compareTo(bNum);
      if (aNum != null) return -1;
      if (bNum != null) return 1;
      return ak.compareTo(bk);
    });

    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      children: [
        TableRow(
          children: visibleEntries
              .map((e) => TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Center(
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ),
                  ))
              .toList(),
        ),
        TableRow(
          children: visibleEntries
              .map((e) => TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Center(child: Text('${e.value}')),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildConsumptionList(List<MaterialEstimate> estimates) {
    if (estimates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Nenhum consumo registrado.',
            style: TextStyle(color: Colors.grey.shade700)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: estimates.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade300),
        itemBuilder: (context, index) {
          final e = estimates[index];
          final piecesStr =
              (e.pieceNames.isNotEmpty) ? e.pieceNames.join(', ') : '-';
          final materialName = e.material;
          final colorName = e.color;
          final meters = e.meters;

          return ListTile(
            title: Text(
              '$materialName ($colorName)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Peças: $piecesStr',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              _formatMeters(meters),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          );
        },
      ),
    );
  }
}
