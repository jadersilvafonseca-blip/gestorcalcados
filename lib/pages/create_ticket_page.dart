// lib/pages/create_ticket_page.dart
import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/data/product_repository.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'package:gestor_calcados_new/models/ticket.dart';
import 'package:gestor_calcados_new/services/material_repository.dart';

class CreateTicketPage extends StatefulWidget {
  final Ticket? ticketToEdit;
  const CreateTicketPage({super.key, this.ticketToEdit});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _clienteCtrl = TextEditingController();
  final _pedidoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  final repo = ProductRepository();
  final _materialRepo = MaterialRepository();
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
    await _materialRepo.init();

    final list = repo.getAll();

    Product? initialProduct;
    if (widget.ticketToEdit != null) {
      initialProduct = list.firstWhereOrNull(
        (p) =>
            p.name == widget.ticketToEdit!.modelo &&
            p.color == widget.ticketToEdit!.cor,
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

  Future<String> _generateNextTicketId() async {
    final currentYear = DateTime.now().year.toString();
    final allTickets = HiveService.getAllTickets();
    final ticketsThisYear = allTickets.where((ticket) {
      final parts = ticket.id.split('-');
      if (parts.length != 2) return false;
      final yearStr = parts[0];
      return yearStr == currentYear;
    }).toList();
    int maxNumber = 0;
    for (final ticket in ticketsThisYear) {
      final parts = ticket.id.split('-');
      final numberStr = parts[1];
      final number = int.tryParse(numberStr);
      if (number != null && number > maxNumber) {
        maxNumber = number;
      }
    }
    final nextNumber = maxNumber + 1;
    final nextNumberFormatted = nextNumber.toString().padLeft(3, '0');
    return '$currentYear-$nextNumberFormatted';
  }

  Future<void> _createOrUpdateTicket(String ticketId) async {
    // 1. O cálculo é feito aqui
    final List<MaterialEstimate> consumption =
        _selected!.estimateMaterialsReadable(totalPares, _materialRepo);

    final t = Ticket(
      id: _isEditing ? widget.ticketToEdit!.id : ticketId,
      cliente: _clienteCtrl.text,
      pedido: _pedidoCtrl.text,
      modelo: _selected!.name,
      marca: _selected!.brand,
      cor: _selected!.color,
      pairs: totalPares,
      grade: {
        for (var n = 34; n <= 43; n++)
          '$n': int.tryParse(_gradeCtrls['$n']!.text) ?? 0
      },
      observacao: _obsCtrl.text,

      // --- CORREÇÃO AQUI ---
      // Esta linha estava comentada. Agora está ATIVA.
      materialsUsed: consumption,
      // --- FIM DA CORREÇÃO ---
    );
    await HiveService.addTicket(t);
  }

  void _clearAllFields() {
    _clienteCtrl.clear();
    _pedidoCtrl.clear();
    _obsCtrl.clear();
    for (var ctrl in _gradeCtrls.values) {
      ctrl.clear();
    }
    setState(() {});
  }

  Future<void> _onSaveTicketOnly() async {
    if (!_validateInput()) return;

    final ticketId =
        _isEditing ? widget.ticketToEdit!.id : await _generateNextTicketId();

    setState(() => _loading = true);

    await _createOrUpdateTicket(ticketId);

    if (mounted) {
      if (_isEditing) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ficha $ticketId salva com sucesso!'),
            backgroundColor: Colors.green[700],
          ),
        );
        _clearAllFields();
        setState(() => _loading = false);
      }
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
                              child: Text(
                                  '${p.name} (${p.color.isNotEmpty ? p.color : 'S/ Cor'})'),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isReady ? _onSaveTicketOnly : null,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _isEditing ? 'Salvar Alterações' : 'Salvar Ficha',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
