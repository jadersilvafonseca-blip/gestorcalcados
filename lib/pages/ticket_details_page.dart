// lib/pages/ticket_details_page.dart (LIMPO E CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/models/ticket.dart';
import 'package:gestor_calcados_new/pages/create_ticket_page.dart';

// --- IMPORTAÇÕES DE PDF REMOVIDAS ---
// (Não são mais necessárias nesta página)
// ------------------------------------

// Importações do modelo de produto que estavam faltando
import 'package:gestor_calcados_new/models/product.dart';
// (O repositório não é mais necessário aqui, pois não geramos PDF)

class TicketDetailsPage extends StatelessWidget {
  final Ticket ticket;

  const TicketDetailsPage({
    super.key,
    required this.ticket,
  });

  // =========================================================
  // LÓGICA DE GERAÇÃO DE PDF FOI TOTALMENTE REMOVIDA DESTE ARQUIVO
  // (Agora ela vive apenas no TicketPdfService.dart)
  // =========================================================
  String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

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
              content: '${ticket.modelo} / ${ticket.cor}',
            ),
            _buildInfoCard(
              title: 'Marca/Cliente',
              content: '${ticket.marca} / ${ticket.cliente}',
            ),
            _buildInfoCard(
              title: 'Total de Pares',
              content: '${ticket.pairs} Pares',
            ),
            _buildInfoCard(
              title: 'Nº do Pedido',
              content: ticket.pedido.isEmpty ? '-' : ticket.pedido,
            ),
            if (ticket.observacao.isNotEmpty)
              _buildInfoCard(
                title: 'Observações',
                content: ticket.observacao,
              ),

            const SizedBox(height: 16),
            Text('GRADE DE PRODUÇÃO',
                style: Theme.of(context).textTheme.titleMedium),
            _buildGradeTable(ticket.grade),

            // MOSTRA O CONSUMO (lendo da ficha)
            if (ticket.materialsUsed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('CONSUMO DE MATERIAIS',
                  style: Theme.of(context).textTheme.titleMedium),
              _buildConsumptionList(ticket.materialsUsed),
            ],

            const SizedBox(height: 24),

            // --- INÍCIO DA MUDANÇA (BOTÕES) ---
            // O Row foi removido
            SizedBox(
              width: double.infinity, // Ocupa a largura toda
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // IMPLEMENTAÇÃO DE EDIÇÃO: Navega para a CreateTicketPage
                  final bool? result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateTicketPage(ticketToEdit: ticket),
                    ),
                  );

                  // Se a tela de edição retornar 'true', significa que foi salvo/atualizado
                  if (result == true) {
                    // É uma boa prática forçar a volta à TicketsPage após a edição
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    }
                  }
                },
                icon: const Icon(Icons.edit),
                label:
                    const Text('Editar Ficha', style: TextStyle(fontSize: 16)),
              ),
            ),
            // O botão de "Gerar PDF Novamente" foi REMOVIDO
            // --- FIM DA MUDANÇA ---
          ],
        ),
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
          Text(content, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGradeTable(Map<String, int> grade) {
    final sortedEntries = grade.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      children: [
        TableRow(
          children: sortedEntries
              .map((e) => TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Center(
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ),
                  ))
              .toList(),
        ),
        TableRow(
          children: sortedEntries
              .map((e) => TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Center(child: Text('${e.value}')),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // Widget para mostrar a lista de consumo (lida da ficha)
  Widget _buildConsumptionList(List<MaterialEstimate> estimates) {
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
          final piecesStr = e.pieceNames.join(', ');

          return ListTile(
            title: Text(
              '${e.material} (${e.color})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Peças: $piecesStr',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              _formatMeters(e.meters),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          );
        },
      ),
    );
  }
}
