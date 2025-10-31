// lib/pages/ticket_details_page.dart (CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/models/ticket.dart';
import 'package:gestor_calcados_new/pages/create_ticket_page.dart';

// Importações de PDF e impressão
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
// ignore: unused_import
import 'package:pdf/pdf.dart';
import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';

// Importações do modelo e repositório de produto que estavam faltando
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/data/product_repository.dart';

class TicketDetailsPage extends StatelessWidget {
  final Ticket ticket;

  const TicketDetailsPage({
    super.key,
    required this.ticket,
  });

  // =========================================================
  // LÓGICA DE GERAÇÃO DE PDF (REIMPRIMIR)
  // =========================================================

  String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

  Future<void> _onGeneratePdf(BuildContext context) async {
    // 1. O PDF é gerado A PARTIR da ficha (ticket) já salva
    final now = DateTime.now();
    final df = DateFormat('dd/MM/yyyy HH:mm');

    // Recupera o objeto Product correspondente para calcular a estimativa
    final Product? product = ProductRepository().getByName(ticket.modelo);

    // Se não encontrar o produto, a estimativa será vazia
    final List<MaterialEstimate> estimates =
        product != null ? product.estimateMaterialsReadable(ticket.pairs) : [];

    // Dados codificados no QR (usando os dados da ficha salva)
    final qrData = {
      'ficha': ticket.id,
      'modelo': ticket.modelo,
      'marca': ticket.marca,
      'cor': ticket.cor,
      'pares': ticket.pairs
    };

    final bc = Barcode.qrCode();
    final qrSvg = bc.toSvg(qrData.toString(), width: 180, height: 180);
    final pdf = pw.Document();

    // Adicionar página PDF (reutilizando a estrutura da create_ticket_page)
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => [
          // Cabeçalho
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FICHA DE PRODUÇÃO',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  // Cliente e Pedido
                  pw.Text(
                      'Cliente: ${ticket.cliente.isEmpty ? "-" : ticket.cliente}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(
                      'Pedido: ${ticket.pedido.isEmpty ? "-" : ticket.pedido}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('Nº: ${ticket.id}',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Data: ${df.format(now)}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Container(
                  width: 120, height: 120, child: pw.SvgImage(svg: qrSvg)),
            ],
          ),
          pw.SizedBox(height: 10),

          // Informações do Produto (Modelo, Cor, Marca)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MODELO: ${ticket.modelo}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('COR: ${ticket.cor.isEmpty ? "-" : ticket.cor}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('MARCA: ${ticket.marca}',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // Grade de Produção e Total de Pares na mesma linha
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GRADE DE PRODUÇÃO',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Total de pares: ${ticket.pairs}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              // Cabeçalho da Grade (34 a 43)
              pw.TableRow(
                children: [
                  for (var n = 34; n <= 43; n++)
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                            child: pw.Text('$n',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)))),
                ],
              ),
              // Valores da Grade
              pw.TableRow(
                children: [
                  for (var n = 34; n <= 43; n++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                          child: pw.Text('${ticket.grade['$n'] ?? 0}',
                              style: const pw.TextStyle())),
                    ),
                ],
              ),
            ],
          ),

          if (ticket.observacao.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('OBSERVAÇÕES:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(ticket.observacao, style: const pw.TextStyle()),
          ],

          // Estimativa de Materiais
          if (product != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('CONSUMO DE MATERIAIS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Column(
                children: estimates.map((e) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '${e.material} ${e.color.isNotEmpty ? "(${e.color})" : ""}',
                            style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(_formatMeters(e.meters),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          pw.SizedBox(height: 12),
          pw.Text('Gerado em ${df.format(now)}',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(onLayout: (_) => bytes);

    // Adiciona o feedback visual para o usuário
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF gerado com sucesso para impressão!')),
    );
  }

  // =========================================================
  // FIM DA LÓGICA DE GERAÇÃO DE PDF
  // =========================================================

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

            const SizedBox(height: 24),

            // Botões de Ação
            Row(
              children: [
                Expanded(
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
                        // E notificar o usuário na tela de listagem
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Ficha'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _onGeneratePdf(
                        context), // Chama a função, passando o context
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Gerar PDF Novamente'),
                  ),
                ),
              ],
            ),
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
}
