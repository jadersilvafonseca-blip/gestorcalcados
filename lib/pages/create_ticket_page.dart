// lib/pages/create_ticket_page.dart (CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';

import 'dart:convert'; // <<< CORREÇÃO 1: Importar o conversor JSON

import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/data/product_repository.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'package:gestor_calcados_new/models/ticket.dart';

class CreateTicketPage extends StatefulWidget {
  final Ticket? ticketToEdit;

  const CreateTicketPage({super.key, this.ticketToEdit});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _clienteCtrl = TextEditingController();
  final _pedidoCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  final repo = ProductRepository();
  List<Product> _products = [];
  Product? _selected;
  bool _loading = true;

  final Map<String, TextEditingController> _gradeCtrls = {
    for (var i = 34; i <= 43; i++) '$i': TextEditingController()
  };

  bool get _isEditing => widget.ticketToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    await HiveService.init();
    await repo.init();
    final list = repo.getAll();

    Product? initialProduct;
    if (widget.ticketToEdit != null) {
      initialProduct = list.firstWhereOrNull(
        (p) => p.name == widget.ticketToEdit!.modelo,
      );
    }

    setState(() {
      _products = list;
      _selected = initialProduct ?? (list.isNotEmpty ? list.first : null);
      _loading = false;

      if (_isEditing) {
        _fillFields(widget.ticketToEdit!);
      }
    });
  }

  void _fillFields(Ticket t) {
    _clienteCtrl.text = t.cliente;
    _pedidoCtrl.text = t.pedido;
    _corCtrl.text = t.cor;
    _obsCtrl.text = t.observacao;

    t.grade.forEach((key, value) {
      if (_gradeCtrls.containsKey(key)) {
        _gradeCtrls[key]!.text = (value == 0) ? '' : value.toString();
      }
    });
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _pedidoCtrl.dispose();
    _corCtrl.dispose();
    _obsCtrl.dispose();
    for (var ctrl in _gradeCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  int get totalPares {
    int total = 0;
    for (var c in _gradeCtrls.values) {
      total += int.tryParse(c.text) ?? 0;
    }
    return total;
  }

  List<MaterialEstimate> get _estimates {
    if (_selected == null) return [];
    return _selected!.estimateMaterialsReadable(totalPares);
  }

  String _formatMeters(double v) =>
      v >= 1 ? '${v.toStringAsFixed(2)} m' : '${v.toStringAsFixed(3)} m';

  bool _validateInput() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o modelo')),
      );
      return false;
    }
    if (totalPares == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a grade de pares')),
      );
      return false;
    }
    return true;
  }

  Future<void> _createOrUpdateTicket(String ticketId) async {
    final t = Ticket(
      id: _isEditing ? widget.ticketToEdit!.id : ticketId,
      cliente: _clienteCtrl.text,
      pedido: _pedidoCtrl.text,
      modelo: _selected!.name,
      marca: _selected!.brand,
      cor: _corCtrl.text,
      pairs: totalPares,
      grade: {
        for (var n = 34; n <= 43; n++)
          '$n': int.tryParse(_gradeCtrls['$n']!.text) ?? 0
      },
      observacao: _obsCtrl.text,
    );
    await HiveService.addTicket(t);
  }

  Future<void> _onSaveTicketOnly() async {
    if (!_validateInput()) return;

    final ticketId = _isEditing
        ? widget.ticketToEdit!.id
        : 'F-${DateTime.now().millisecondsSinceEpoch}';

    await _createOrUpdateTicket(ticketId);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  //
  // ====================================================================
  // <<< CORREÇÃO 2: Alteração na função de gerar o PDF >>>
  // ====================================================================
  //
  Future<void> _onGeneratePdf() async {
    if (!_validateInput()) return;

    final ticketId = _isEditing
        ? widget.ticketToEdit!.id
        : 'F-${DateTime.now().millisecondsSinceEpoch}';

    final now = DateTime.now();
    final df = DateFormat('dd/MM/yyyy HH:mm');

    await _createOrUpdateTicket(ticketId);

    // Mapeia os dados para o formato JSON que o scanner ESPERA
    final qrData = {
      'id': ticketId, // <--- MUDADO (era 'ficha')
      'modelo': _selected!.name,
      'marca': _selected!.brand,
      'cor': _corCtrl.text.trim(),
      'pairs': totalPares // <--- MUDADO (era 'pares', o scanner espera 'pairs')
    };

    final bc = Barcode.qrCode();
    // Converte o Map para uma string JSON VÁLIDA
    final qrJsonString = json.encode(qrData);

    final qrSvg = bc.toSvg(qrJsonString, width: 180, height: 180);
    // ====================================================================
    // <<< FIM DA CORREÇÃO >>>
    // ====================================================================

    final pdf = pw.Document();

    // Adicionar página PDF (lógica original)
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
                      'Cliente: ${_clienteCtrl.text.isEmpty ? "-" : _clienteCtrl.text}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(
                      'Pedido: ${_pedidoCtrl.text.isEmpty ? "-" : _pedidoCtrl.text}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text('Nº: $ticketId',
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
                pw.Text('MODELO: ${_selected!.name}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('COR: ${_corCtrl.text.isEmpty ? "-" : _corCtrl.text}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('MARCA: ${_selected!.brand}',
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
              pw.Text('Total de pares: $totalPares',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 6),
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
                    () {
                      final text = _gradeCtrls['$n']?.text ?? '';
                      final pdfText = text.isEmpty ? '0' : text;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(pdfText, style: const pw.TextStyle()),
                        ),
                      );
                    }(),
                ],
              ),
            ],
          ),

          if (_obsCtrl.text.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('OBSERVAÇÕES:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(_obsCtrl.text, style: const pw.TextStyle()),
          ],

          pw.SizedBox(height: 10),
          pw.Text('CONSUMO DE MATERIAIS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            child: pw.Column(
              children: (_estimates).map((e) {
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

          pw.SizedBox(height: 12),
          pw.Text('Gerado em ${df.format(now)}',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(onLayout: (_) => bytes);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _selected != null && totalPares > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Editar Ficha ${widget.ticketToEdit!.id}'
            : 'Gerar Nova Ficha'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<Product>(
                    value: _selected,
                    items: _products
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.name} (${p.brand})'),
                            ))
                        .toList(),
                    onChanged: _isEditing
                        ? null
                        : (v) => setState(() => _selected = v),
                    decoration: InputDecoration(
                      labelText: 'Modelo',
                      helperText: _isEditing
                          ? 'Modelo não pode ser alterado na edição'
                          : null,
                    ),
                  ),
                  TextField(
                    controller: _corCtrl,
                    decoration: const InputDecoration(labelText: 'Cor'),
                  ),
                  TextField(
                    controller: _clienteCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cliente (opcional)'),
                  ),
                  TextField(
                    controller: _pedidoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nº do Pedido (opcional)'),
                  ),
                  TextField(
                    controller: _obsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Observação (se houver)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Text('Grade de produção (pares por numeração)',
                      style: Theme.of(context).textTheme.titleMedium),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var n = 34; n <= 43; n++)
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _gradeCtrls['$n'],
                            decoration: InputDecoration(labelText: '$n'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Total de pares: $totalPares',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isReady ? _onSaveTicketOnly : null,
                          icon: const Icon(Icons.save),
                          label: Text(_isEditing
                              ? 'Salvar Alterações'
                              : 'Salvar Ficha'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isReady ? _onGeneratePdf : null,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Gerar PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// Extensão auxiliar para a busca do produto
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
