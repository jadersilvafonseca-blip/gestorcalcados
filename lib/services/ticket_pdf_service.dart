// lib/services/ticket_pdf_service.dart
import 'package:intl/intl.dart';
// As duas importações de PDF
import 'package:pdf/pdf.dart'; // Contém PdfTextOverflow
import 'package:pdf/widgets.dart' as pw; // Contém pw.Text
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'dart:convert';

// --- MUDANÇA: Imports dos novos modelos do Firebase ---
import 'package:gestor_calcados_new/models/product_model.dart';
import 'package:gestor_calcados_new/models/ticket_model.dart';
// --- FIM DA MUDANÇA ---

// As classes/funções _Repositories e _getRepositories foram REMOVIDAS
// pois eram específicas do Hive.

class TicketPdfService {
  // Helper para formatar metros
  static String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

  /// Gera um PDF com múltiplas fichas, 2 por página.
  // --- MUDANÇA: Recebe a nova lista de TicketModel ---
  static Future<void> generateBatchPdf(List<TicketModel> tickets) async {
    // --- FIM DA MUDANÇA ---
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    // Removemos a busca aos repositórios, pois não é mais necessária.
    // O TicketModel já tem tudo que precisamos (inclusive o materialsUsed).

    for (int i = 0; i < tickets.length; i += 2) {
      final ticket1 = tickets[i];
      // O product1 não é realmente usado no _buildFichaWidget,
      // exceto para uma verificação de 'null'. Podemos passar null.
      final ProductModel? product1 = null;

      final TicketModel? ticket2 =
          (i + 1 < tickets.length) ? tickets[i + 1] : null;
      final ProductModel? product2 = null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // --- FICHA 1 (METADE DE CIMA) ---
                pw.Expanded(
                  flex: 1,
                  child: _buildFichaWidget(
                    ticket1,
                    product1,
                    df.format(now),
                    // materialRepo não é mais necessário
                  ),
                ),
                pw.Divider(
                    height: 10,
                    thickness: 1,
                    borderStyle: pw.BorderStyle.dashed),
                // --- FICHA 2 (METADE DE BAIXO) ---
                pw.Expanded(
                  flex: 1,
                  child: ticket2 != null
                      ? _buildFichaWidget(
                          ticket2,
                          product2,
                          df.format(now),
                          // materialRepo não é mais necessário
                        )
                      : pw.Center(child: pw.Text('')),
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
        name: 'Fichas_Producao.pdf',
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- HELPER para desenhar UM item de consumo ---
  // (Esta função não muda, pois MaterialEstimate é o mesmo)
  static pw.Widget _buildConsumptionItem(MaterialEstimate e) {
    final piecesStr = e.pieceNames.join(', ');

    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Flexible(
                child: pw.Text(
                    '${e.material} ${e.color.isNotEmpty ? "(${e.color})" : ""}',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(width: 8),
              pw.Text(_formatMeters(e.meters),
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8)),
            ],
          ),
          if (piecesStr.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8.0, top: 2.0),
              child: pw.Text(
                'Peças: $piecesStr',
                style:
                    const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }

  /// Desenha o layout de UMA ÚNICA ficha
  // --- MUDANÇA: Recebe TicketModel e remove materialRepo ---
  static pw.Widget _buildFichaWidget(
    TicketModel ticket,
    ProductModel? product,
    String dataGeracao,
    // MaterialRepository materialRepo, // REMOVIDO
  ) {
    // --- FIM DA MUDANÇA ---

    // 1. Gerar QR Code
    // --- MUDANÇA: Usa os campos do TicketModel ---
    final qrData = {
      'id': ticket.id,
      'modelo': ticket.productName, // MUDOU
      'marca': ticket.productReference, // MUDOU
      'cor': ticket.productColor, // MUDOU
      'pairs': ticket.pairs
    };
    // --- FIM DA MUDANÇA ---

    final qrJsonString = json.encode(qrData);
    final bc = Barcode.qrCode();
    final qrSvg = bc.toSvg(qrJsonString, width: 90, height: 90);

    // 2. Obter estimativas (AGORA VEM DIRETO DO TICKETMODEL)
    final List<MaterialEstimate> estimates = ticket.materialsUsed;

    // 3. Construir o layout
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // --- PARTE 1: CONTEÚDO FIXO (Layout revisado) ---
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
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
                  pw.Text('Data: $dataGeracao',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Container(
                  width: 90, height: 90, child: pw.SvgImage(svg: qrSvg)),
            ],
          ),

          pw.SizedBox(height: 10),

          // Informações do Produto (Acima da grade)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // --- MUDANÇA: Usa os campos do TicketModel ---
                pw.Text('MODELO: ${ticket.productName}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'COR: ${ticket.productColor.isEmpty ? "-" : ticket.productColor}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'MARCA: ${ticket.productReference}', // MUDOU (era marca)
                    style: const pw.TextStyle(fontSize: 12)),
                // --- FIM DA MUDANÇA ---
              ],
            ),
          ),
          // Tabela da Grade (manter as linhas)
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
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
              pw.TableRow(
                children: [
                  for (var n = 34; n <= 43; n++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                        child: pw.Text((ticket.grade['$n'] ?? 0).toString(),
                            style: const pw.TextStyle()),
                      ),
                    ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // Observações e Total de Pares (lado a lado)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Coluna da Esquerda: Observações
              pw.Expanded(
                flex: 2,
                child: (ticket.observacao.isNotEmpty)
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                            pw.Text('OBSERVAÇÕES:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10)),
                            pw.Text(ticket.observacao,
                                style: const pw.TextStyle(fontSize: 10)),
                          ])
                    : pw.Container(),
              ),
              pw.SizedBox(width: 10),
              // Coluna da Direita: Total de Pares
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total de pares:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('${ticket.pairs}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ]),
              ),
            ],
          ),
        ]),

        pw.SizedBox(height: 10),

        // --- PARTE 2: CONSUMO (Layout de 2 colunas, SEM bordas) ---
        pw.Text('CONSUMO DE MATERIAIS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),

        pw.Expanded(
          child:
              // O CONTAINER FOI MANTIDO, MAS SEM A DECORATION/BORDA
              pw.Container(
            child: (estimates.isEmpty)
                ? pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                        (product == null && ticket.materialsUsed.isEmpty)
                            ? '(Modelo não encontrado)'
                            : '(Sem consumo)',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  )
                : pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // --- COLUNA 1 ---
                      pw.Expanded(
                        flex: 1,
                        child: pw.ListView.builder(
                          itemCount: (estimates.length / 2).ceil(),
                          itemBuilder: (context, index) {
                            return _buildConsumptionItem(estimates[index]);
                          },
                        ),
                      ),
                      pw.SizedBox(width: 4),

                      // --- REMOVIDO: pw.VerticalDivider(width: 1, color: PdfColors.grey600),

                      pw.SizedBox(width: 4),

                      // --- COLUNA 2 ---
                      pw.Expanded(
                        flex: 1,
                        child: pw.ListView.builder(
                          itemCount: (estimates.length / 2).floor(),
                          itemBuilder: (context, index) {
                            final int realIndex =
                                (estimates.length / 2).ceil() + index;
                            return _buildConsumptionItem(estimates[realIndex]);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// Extensão auxiliar (NÃO MUDOU)
extension IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
