import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show MissingPluginException, ByteData;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
// Este é o import CORRETO
import 'package:gestor_calcados_new/models/ticket_model.dart';

class PdfResult {
  final bool ok;
  final String? message;
  final String? path;
  const PdfResult({required this.ok, this.message, this.path});
}

class PdfService {
  // Esta é a função CORRETA para PDF agrupado
  static Future<PdfResult> generateAndShareBatchPdf(
      List<TicketModel> tickets) async {
    debugPrint('--- [PdfService] EXECUTANDO A FUNÇÃO DE LOTE (AGRUPADO) ---');
    debugPrint(
        '--- [PdfService] Número de fichas recebidas: ${tickets.length} ---');

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    // ============================================================
    // --- RODAPÉ REMOVIDO (LINHAS COMENTADAS) ---
    // ============================================================
    // final nowDf = DateFormat('dd/MM/yyyy HH:mm');
    // final footerText =
    //     'Gerado em ${nowDf.format(DateTime.now())} • Minha Produção';

    final doc = pw.Document();
    for (int i = 0; i < tickets.length; i += 2) {
      final first = tickets[i];
      final second = (i + 1 < tickets.length) ? tickets[i + 1] : null;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          theme: theme,
          // ============================================================
          // --- CORREÇÃO DO ERRO 'footer' ---
          // O rodapé foi REMOVIDO daqui...
          // ============================================================
          build: (context) {
            // ...e foi MOVIDO para dentro do 'build'
            return pw.Column(
              children: [
                // Este Expanded contém as duas fichas e o separador
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Expanded(child: _fichaLayout(first)),
                      pw.SizedBox(height: 8),
                      _dottedSeparatorFullWidth(),
                      pw.SizedBox(height: 8),
                      if (second != null)
                        pw.Expanded(child: _fichaLayout(second))
                      else
                        pw.Expanded(child: pw.Container()),
                    ],
                  ),
                ),
                // ============================================================
                // --- Rodapé MOVIDO PARA CÁ ---
                // --- AGORA REMOVIDO (BLOCO COMENTADO) ---
                // ============================================================
                // pw.Container(
                //   alignment: pw.Alignment.center,
                //   padding: const pw.EdgeInsets.only(top: 8.0),
                //   decoration: const pw.BoxDecoration(
                //     border: pw.Border(
                //         top: pw.BorderSide(
                //             color: PdfColors.grey400, width: 0.5)),
                //   ),
                //   child: pw.Text(
                //     footerText,
                //     style: const pw.TextStyle(
                //         fontSize: 8.5, color: PdfColors.grey600),
                //   ),
                // ),
              ],
            );
          },
        ),
      );
    }

    return await _saveOrShare(
        doc, 'fichas_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  // Esta é a função CORRETA para PDF único
  static Future<PdfResult> generateAndShareTicket(TicketModel t) async {
    debugPrint('--- [PdfService] EXECUTANDO A FUNÇÃO DE FICHA ÚNICA ---');

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    // ============================================================
    // --- RODAPÉ REMOVIDO (LINHAS COMENTADAS) ---
    // ============================================================
    // final nowDf = DateFormat('dd/MM/yyyy HH:mm');
    // final footerText =
    //     'Gerado em ${nowDf.format(DateTime.now())} • Minha Produção';

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(16),
      theme: theme,
      // ============================================================
      // --- CORREÇÃO DO ERRO 'footer' ---
      // O rodapé foi REMOVIDO daqui...
      // ============================================================
      build: (_) {
        // ...e foi MOVIDO para dentro do 'build'
        return pw.Column(
          children: [
            pw.Expanded(child: _fichaLayout(t)), // A ficha ocupa o espaço
            // ============================================================
            // --- Rodapé MOVIDO PARA CÁ ---
            // --- AGORA REMOVIDO (BLOCO COMENTADO) ---
            // ============================================================
            // pw.Container(
            //   alignment: pw.Alignment.center,
            //   margin: const pw.EdgeInsets.only(top: 10.0),
            //   padding: const pw.EdgeInsets.only(top: 8.0),
            //   decoration: const pw.BoxDecoration(
            //     border: pw.Border(
            //         top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            //   ),
            //   child: pw.Text(
            //     footerText,
            //     style:
            //         const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
            //   ),
            // ),
          ],
        );
      },
    ));
    return await _saveOrShare(doc, 'ficha_${t.id}.pdf');
  }

  // Este é o layout CORRETO com seus ajustes
  static pw.Widget _fichaLayout(TicketModel t) {
    final total = _sumGrade(t.grade) ?? t.pairs;
    final qrPayload =
        'TKT|${t.id}|${t.productName}|${t.productColor}|${t.productReference}|$total';
    final qr = Barcode.qrCode();
    final qrSvg = qr.toSvg(qrPayload, width: 160, height: 160);

    const referencia = '—';
    final cliente = (t.cliente.isNotEmpty) ? t.cliente : '—';

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FICHA DE PRODUÇÃO',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _kv('Nº Ficha', t.id),
                    _kv('Cliente', cliente),
                    _kv('Data',
                        _formatTimestampForDisplay(t.lastMovedAt, null)),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              // QR Code (sem borda)
              pw.Container(
                width: 64,
                height: 64,
                child: pw.Center(child: pw.SvgImage(svg: qrSvg)),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Linha REF / MODELO / COR / MARCA
          pw.Text(
            'REF: ${t.productReference.isNotEmpty ? t.productReference : '—'}  •  MODELO: ${t.productName}  •  COR: ${t.productColor}',
            style: const pw.TextStyle(fontSize: 10.5),
          ),
          pw.SizedBox(height: 3),
          _gradeTable(t),
          // Total de pares (sem borda e alinhado à direita)
          pw.Row(
            children: [
              pw.Spacer(),
              pw.Text(
                'TOTAL DE PARES: $total',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Bloco de Consumo de Materiais
          pw.Text('CONSUMO DE MATERIAIS',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          // Usamos Flexible/Expanded para o consumo ocupar o espaço restante
          pw.Flexible(
            child: _buildConsumptionColumns(t),
          ),
        ],
      ),
    );
  }

  static int? _sumGrade(Map<String, int> grade) {
    if (grade.isEmpty) return null;
    var s = 0;
    for (final v in grade.values) {
      s += (v);
    }
    return s;
  }

  static pw.Widget _kv(String k, String v) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 100,
            child: pw.Text(
              k,
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      );

  static pw.Widget _gradeTable(TicketModel t) {
    // Corrigido para garantir que as chaves sejam strings (como 34, 35...)
    final keys = t.grade.keys.toList();
    // Tenta ordenar numericamente
    try {
      keys.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    } catch (e) {
      keys.sort(); // Fallback para ordenação de string
    }

    final numeros = keys;

    if (numeros.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration:
            pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
        child: pw.Text(
          'Sem grade informada.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      );
    }

    final headers = pw.Row(
      children: numeros
          .map((n) => _cell(n.toString(),
              bold: true, center: true, pad: 5, fontSize: 10))
          .toList(),
    );
    final valores = pw.Row(
      children: numeros
          .map((n) =>
              _cell('${t.grade[n] ?? 0}', center: true, pad: 6, fontSize: 11))
          .toList(),
    );
    return pw.Column(children: [headers, valores]);
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    bool center = false,
    double pad = 6,
    double fontSize = 11,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: pw.EdgeInsets.all(pad),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildConsumptionColumns(TicketModel t) {
    final items = t.materialsUsed;
    if (items.isEmpty) {
      return pw.Text('(Sem consumo de materiais)',
          style: pw.TextStyle(fontSize: 9));
    }

    items.sort((a, b) => a.material.compareTo(b.material));

    final half = (items.length / 2).ceil();
    final left = items.sublist(0, half);
    final right = items.sublist(half);

    pw.Widget columnOf(List<MaterialEstimate> list) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: list.map((m) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${m.material} (${m.color})',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Peças: ${m.pieceNames.join(', ')}',
                          style: pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Container(
                  width: 72,
                  alignment: pw.Alignment.topRight,
                  child: pw.Text(
                      '${m.meters.toStringAsFixed(2).replaceAll('.', ',')} m',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: columnOf(left)),
        pw.SizedBox(width: 18),
        pw.Expanded(child: columnOf(right)),
      ],
    );
  }

  static pw.Widget _dottedSeparatorFullWidth() {
    const dots = 72;
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: List.generate(dots, (i) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 1),
            child: pw.Container(
              width: 2,
              height: 2,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey,
                shape: pw.BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }

  static Future<PdfResult> _saveOrShare(
      pw.Document doc, String filename) async {
    try {
      final bytes = await doc.save();
      debugPrint('[PdfService] bytes gerados: ${bytes.length}');

      if (kIsWeb) {
        try {
          await Printing.layoutPdf(
              onLayout: (format) async => bytes, name: filename);
          return const PdfResult(ok: true, message: 'PDF aberto no navegador.');
        } catch (e, st) {
          debugPrint('[PdfService] erro web layoutPdf: $e\n$st');
          return PdfResult(
              ok: false, message: 'Erro abrir PDF no navegador: $e');
        }
      }

      try {
        await Printing.sharePdf(bytes: bytes, filename: filename)
            .timeout(const Duration(seconds: 12));
        return const PdfResult(ok: true, message: 'PDF compartilhado.');
      } on MissingPluginException catch (e) {
        debugPrint('[PdfService] missing plugin sharePdf: $e');
      } on TimeoutException catch (e) {
        debugPrint('[PdfService] timeout sharePdf: $e');
      } catch (e, st) {
        debugPrint('[PdfService] erro sharePdf: $e\n$st');
      }

      try {
        final tmp = await getTemporaryDirectory();
        final path = '${tmp.path}/$filename';
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('[PdfService] PDF salvo: $path');
        return PdfResult(ok: true, message: 'PDF salvo em: $path', path: path);
      } catch (e, st) {
        debugPrint('[PdfService] erro salvar PDF: $e\n$st');
        return PdfResult(ok: false, message: 'Erro ao salvar PDF: $e');
      }
    } catch (e, st) {
      debugPrint('[PdfService] ERRO GERAL: $e\n$st');
      return PdfResult(ok: false, message: 'Falha ao gerar PDF: $e');
    }
  }

  static String _formatTimestampForDisplay(dynamic maybeTs, dynamic d) {
    if (maybeTs == null) return '??';
    try {
      if (maybeTs is Timestamp) {
        final d = maybeTs.toDate().toLocal();
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
      } else if (maybeTs is DateTime) {
        final d = maybeTs.toLocal();
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
      } else {
        final s = maybeTs.toString();
        if (s.startsWith('Timestamp(')) return s;
        final parsed = DateTime.parse(s).toLocal();
        return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} '
            '${parsed.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return maybeTs.toString();
    }
  }
}
