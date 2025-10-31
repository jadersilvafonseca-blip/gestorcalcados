// lib/services/pdf_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';

import '../models/ticket.dart';

class PdfResult {
  final bool ok;
  final String? path;
  final String? message;
  const PdfResult({required this.ok, this.path, this.message});
}

class PdfService {
  /// Gera a ficha em PDF (A5) e tenta compartilhar.
  /// Se não conseguir, salva localmente e retorna o caminho.
  static Future<PdfResult> generateAndShareTicket(
    Ticket t, {
    bool twoPerA4 = true,
    double titleScale = 0.9,
  }) async {
    try {
      final doc = pw.Document();
      final ficha = _ticketA5(t, titleScale: titleScale);

      if (twoPerA4) {
        // 2 fichas por página A4
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                ficha,
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.6, color: PdfColors.grey600),
                pw.SizedBox(height: 8),
                ficha,
              ],
            ),
          ),
        );
      } else {
        // 1 ficha por página A5
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a5,
            margin: const pw.EdgeInsets.all(16),
            build: (_) => ficha,
          ),
        );
      }

      final bytes = await doc.save();
      final fileName = 'ficha_${t.id}.pdf';

      // 1) Tenta compartilhar
      try {
        await Printing.sharePdf(bytes: bytes, filename: fileName)
            .timeout(const Duration(seconds: 10));
        return const PdfResult(ok: true, message: 'PDF compartilhado.');
      } on MissingPluginException {
        // plugin não disponível ainda — segue para salvar
      } on TimeoutException {
        // timeout — segue para salvar
      } catch (e) {
        debugPrint('[PdfService] Falha ao compartilhar: $e');
      }

      // 2) Fallback: salvar local
      String? savedPath;
      try {
        final tmp = await getTemporaryDirectory();
        final file = File('${tmp.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      } catch (e) {
        debugPrint('[PdfService] Erro ao salvar PDF: $e');
      }

      return PdfResult(
        ok: false,
        path: savedPath,
        message: savedPath == null
            ? 'PDF gerado, mas não foi possível salvar.'
            : 'PDF salvo em:\n$savedPath',
      );
    } catch (e, st) {
      debugPrint('[PdfService] ERRO GERAL: $e\n$st');
      return PdfResult(ok: false, message: 'Falha ao gerar PDF: $e');
    }
  }

  // ----------------------- Construção visual -----------------------

  static pw.Widget _ticketA5(Ticket t, {double titleScale = 0.9}) {
    final nowDf = DateFormat('dd/MM/yyyy HH:mm');

    // total: soma da grade (se houver) senão usa pairs
    final total = _sumGrade(t.grade) ?? t.pairs;

    // payload do QR conforme sua descrição (id + total + modelo/cor/marca)
    final qrPayload =
        'TKT|${t.id}|${t.modelo}|${t.cor}|${t.marca}|$total'; // formato: TK|id|modelo|cor|marca|total
    final qr = Barcode.qrCode();
    final qrSvg = qr.toSvg(qrPayload, width: 160, height: 160);

    // "referência" não existe no seu Ticket: mostra traço
    const referencia = '—';
    final cliente = (t.cliente.isNotEmpty) ? t.cliente : '—';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
      ),
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
                        fontSize: 22 * titleScale,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Gestor de Calçados',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _kv('Nº Ficha', t.id),
                    _kv('Cliente', cliente),
                    _kv('Total de pares', '$total'),
                    _kv('Entrega', '—'), // não há campo de entrega no Ticket
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                width: 120,
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                      ),
                      child: pw.Center(child: pw.SvgImage(svg: qrSvg)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'QR: $qrPayload',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'REF: $referencia  •  MODELO: ${t.modelo}  •  COR: ${t.cor}  •  MARCA: ${t.marca}',
            style: const pw.TextStyle(fontSize: 10.5),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Grade (pares por numeração)',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 3),
          _gradeTable(t),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Text(
              'TOTAL DE PARES: $total',
              style: pw.TextStyle(
                fontSize: 13.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Gerado em ${nowDf.format(DateTime.now())} • App Gestor de Calçados',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ----------------------- Helpers -----------------------

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

  static pw.Widget _gradeTable(Ticket t) {
    final numeros = (t.grade.keys.toList()..sort());
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
}
