// lib/services/ticket_pdf_service.dart
import 'package:gestor_calcados_new/data/product_repository.dart';
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/models/ticket.dart';
import 'package:gestor_calcados_new/services/material_repository.dart';
import 'package:intl/intl.dart';
// As duas importações de PDF
import 'package:pdf/pdf.dart'; // <--- Contém PdfTextOverflow
import 'package:pdf/widgets.dart' as pw; // <--- Contém pw.Text
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'dart:convert';

// --- CORREÇÃO: Classe auxiliar para substituir os "Records" do Dart 3 ---
/// Classe auxiliar privada para agrupar os repositórios.
class _Repositories {
  final Map<String, Product> productMap;
  final MaterialRepository materialRepo;
  _Repositories(this.productMap, this.materialRepo);
}
// --- FIM DA CORREÇÃO ---

class TicketPdfService {
  // Helper para formatar metros
  static String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

  // Helper para buscar os repositórios
  // --- CORREÇÃO: Mudança do tipo de retorno (de Record para a classe) ---
  static Future<_Repositories> _getRepositories() async {
    final materialRepo = MaterialRepository();
    await materialRepo.init();

    final productRepo = ProductRepository();
    try {
      await productRepo.init();
    } catch (e) {
      // print('Repo de produto já iniciado ou não tem init: $e');
    }
    final allProducts = productRepo.getAll();
    final productMap = {for (var p in allProducts) p.name: p};

    // Retorna a instância da classe auxiliar
    return _Repositories(productMap, materialRepo);
  }

  /// Gera um PDF com múltiplas fichas, 2 por página.
  static Future<void> generateBatchPdf(List<Ticket> tickets) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    // --- CORREÇÃO: Ajuste na chamada da função e na extração dos dados ---
    final repos = await _getRepositories();
    final productMap = repos.productMap;
    final materialRepo = repos.materialRepo;
    // --- FIM DA CORREÇÃO ---

    for (int i = 0; i < tickets.length; i += 2) {
      final ticket1 = tickets[i];
      final product1 = productMap[ticket1.modelo];

      final Ticket? ticket2 = (i + 1 < tickets.length) ? tickets[i + 1] : null;
      final Product? product2 =
          ticket2 != null ? productMap[ticket2.modelo] : null;

      pdf.addPage(
        pw.Page(
          // Mantendo o pageFormat: PdfPageFormat.a4 para máxima compatibilidade
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
                    materialRepo,
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
                          materialRepo,
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
  static pw.Widget _buildFichaWidget(
    Ticket ticket,
    Product? product,
    String dataGeracao,
    MaterialRepository materialRepo,
  ) {
    // 1. Gerar QR Code
    final qrData = {
      'id': ticket.id,
      'modelo': ticket.modelo,
      'marca': ticket.marca,
      'cor': ticket.cor,
      'pairs': ticket.pairs
    };
    final qrJsonString = json.encode(qrData);
    final bc = Barcode.qrCode();
    final qrSvg = bc.toSvg(qrJsonString, width: 90, height: 90);

    // 2. Obter estimativas
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
                pw.Text('MODELO: ${ticket.modelo}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('COR: ${ticket.cor.isEmpty ? "-" : ticket.cor}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('MARCA: ${ticket.marca}',
                    style: const pw.TextStyle(fontSize: 12)),
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
                        product == null && ticket.materialsUsed.isEmpty
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

// Extensão auxiliar
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
