import 'package:flutter/material.dart';
// --- NOVOS IMPORTS DO FIREBASE ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/product_model.dart'; // O nosso "molde" de Produto
import 'package:gestor_calcados_new/models/ticket_model.dart'; // O nosso "molde" de Ficha

// --- MUDANÇA: IMPORTA O MODELO DE MATERIAL DO FIREBASE ---
import 'package:gestor_calcados_new/models/material_model.dart';
// import 'package:gestor_calcados_new/models/material_item.dart'; // REMOVIDO
// ---------------------------------

import 'package:gestor_calcados_new/services/material_repository.dart';

class CreateTicketPage extends StatefulWidget {
  final AppUserModel user;
  final dynamic ticketToEdit;
  const CreateTicketPage({super.key, required this.user, this.ticketToEdit});

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final _clienteCtrl = TextEditingController();
  final _pedidoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  List<ProductModel> _products = [];
  ProductModel? _selected;
  bool _isLoading = true;
  late bool _isEditing;

  final _materialRepo = MaterialRepository();

  // --- MUDANÇA: Cache de materiais (para substituir a leitura síncrona do Hive) ---
  List<MaterialModel> _allMaterials = [];
  // --- FIM DA MUDANÇA ---

  final Map<String, TextEditingController> _gradeCtrls = {
    for (var i = 34; i <= 43; i++) '$i': TextEditingController()
  };

  @override
  void initState() {
    super.initState();
    _isEditing = widget.ticketToEdit != null;
    _loadPrerequisites();
  }

  // --- MUDANÇA: Carrega PRODUTOS (Firestore) e MATERIAIS (Firestore) ---
  Future<void> _loadPrerequisites() async {
    try {
      // 1. Carrega o repositório de materiais (do Firestore, para o cache)
      // await _materialRepo.init(); // REMOVIDO
      _allMaterials = await _materialRepo.getAll(widget.user.teamId);

      // 2. Carrega os produtos (do Firestore)
      // !! EXIGE ÍNDICE COMPOSTO: 'products' -> teamId (Crescente), name (Crescente) !!
      final query = await FirebaseFirestore.instance
          .collection('products')
          .where('teamId', isEqualTo: widget.user.teamId)
          .orderBy('name')
          .get();

      final list =
          query.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

      if (mounted) {
        setState(() {
          _products = list;
          _selected = (list.isNotEmpty ? list.first : null);
          _isLoading = false;
        });
        if (widget.ticketToEdit != null) {
          _populateFromTicket(widget.ticketToEdit);
        }
      } else {
        _products = list;
        _selected = (list.isNotEmpty ? list.first : null);
        _isLoading = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar pré-requisitos: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      } else {
        _isLoading = false;
      }
    }
  }
  // --- FIM DA MUDANÇA ---

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
        const SnackBar(
            content: Text('Selecione o modelo'),
            backgroundColor: Colors.orange),
      );
      return false;
    }
    if (totalPares == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Informe a grade de pares'),
            backgroundColor: Colors.orange),
      );
      return false;
    }
    return true;
  }

  Future<String> _generateNextTicketId() async {
    final currentYear = DateTime.now().year.toString();

    // !! EXIGE ÍNDICE COMPOSTO: 'tickets' -> teamId (Crescente), id (Decrescente) !!
    final query = await FirebaseFirestore.instance
        .collection('tickets')
        .where('teamId', isEqualTo: widget.user.teamId)
        .where('id', isGreaterThanOrEqualTo: '$currentYear-000')
        .where('id', isLessThanOrEqualTo: '$currentYear-999')
        .orderBy('id', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return '$currentYear-001'; // Primeira ficha do ano
    }

    final lastId = query.docs.first.id;
    final lastNumber = int.tryParse(lastId.split('-')[1]) ?? 0;
    final nextNumber = lastNumber + 1;
    final nextNumberFormatted = nextNumber.toString().padLeft(3, '0');
    return '$currentYear-$nextNumberFormatted';
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

  // --- MUDANÇA: CÁLCULO DE MATERIAIS (Lógica do cache do Firestore) ---
  List<MaterialEstimate> _estimateMaterials(
      ProductModel product, int totalPairs) {
    if (totalPairs <= 0) return [];

    final Map<String, Map<String, dynamic>> summary = {};

    for (final piece in product.pieces) {
      final materialName = (piece.material).toString();
      final colorName = (piece.color).toString();
      final area = (piece.areaPerPair);

      if (materialName.isEmpty) continue;

      // --- MUDANÇA: Busca o material no cache síncrono ---
      MaterialModel? materialData;
      try {
        materialData = _allMaterials.firstWhere((m) =>
            m.name.toLowerCase().trim() == materialName.toLowerCase().trim());
      } catch (e) {
        materialData = null; // Material não encontrado no cache
      }
      // --- FIM DA MUDANÇA ---

      if (materialData == null) continue; // Material não encontrado

      final key = '$materialName||$colorName';
      final current = summary[key] ?? {'meters': 0.0, 'pieces': <String>{}};

      // Usa o 'height' do MaterialModel
      final metersPerPair = (area > 0) ? (area / (materialData.height)) : 0.0;
      final totalMeters = metersPerPair * totalPairs;

      final double newMeters = (current['meters'] as double) + totalMeters;
      final Set<String> newPieces =
          Set<String>.from(current['pieces'] as Set<String>)..add(piece.name);

      summary[key] = {'meters': newMeters, 'pieces': newPieces};
    }

    // Converte o mapa de resumo para a lista final
    return summary.entries.map((entry) {
      final parts = entry.key.split('||');
      final meters = entry.value['meters'] as double;
      final pieces = entry.value['pieces'] as Set<String>;
      return MaterialEstimate(
        material: parts[0],
        color: parts[1],
        meters: meters,
        pieceNames: pieces.toList()..sort(),
      );
    }).toList();
  }
  // --- FIM DA MUDANÇA ---

  Future<void> _onSaveTicketOnly() async {
    if (!_validateInput()) return;

    setState(() => _isLoading = true);

    try {
      final ticketId = await _generateNextTicketId();

      final Map<String, int> gradeMap = {
        for (var n = 34; n <= 43; n++)
          '$n': int.tryParse(_gradeCtrls['$n']!.text) ?? 0
      };

      // --- MUDANÇA: Calcula o consumo de materiais (agora usa o cache) ---
      final List<MaterialEstimate> consumption =
          _estimateMaterials(_selected!, totalPares);
      // --- FIM DA MUDANÇA ---

      final newTicket = TicketModel(
        id: ticketId,
        teamId: widget.user.teamId,
        productId: _selected!.id,
        productName: _selected!.name,
        productReference: _selected!.reference,
        productColor: _selected!.color,
        pairs: totalPares,
        createdAt: Timestamp.now(), // <-- ESTÁ CORRETO
        createdByUid: widget.user.uid,
        status: TicketStatus.created,
        currentSectorId: 'created',
        currentSectorName: 'Criada',
        lastMovedAt: Timestamp.now(), // <-- ESTÁ CORRETO
        history: [],
        cliente: _clienteCtrl.text.trim(),
        pedido: _pedidoCtrl.text.trim(),
        observacao: _obsCtrl.text.trim(),
        grade: gradeMap,
        materialsUsed: consumption, // <-- SALVA A LISTA DE CONSUMO
      );

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(ticketId)
          .set(newTicket.toFirestore());

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
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar ficha: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Popula campos (esta função não precisa de mudanças)
  void _populateFromTicket(dynamic t) {
    try {
      final cliente = t.cliente ?? t.clientName ?? t['cliente'] ?? '';
      final pedido = t.pedido ?? t.orderId ?? t['pedido'] ?? '';
      final observacao = t.observacao ?? t.observation ?? t['observacao'] ?? '';

      _clienteCtrl.text = cliente.toString();
      _pedidoCtrl.text = pedido.toString();
      _obsCtrl.text = observacao.toString();

      final gradeMap = t.grade ?? t['grade'] ?? <String, dynamic>{};
      if (gradeMap is Map) {
        for (var key in gradeMap.keys) {
          final k = key.toString();
          final v = (gradeMap[key] is int)
              ? gradeMap[key] as int
              : int.tryParse('${gradeMap[key]}') ?? 0;
          if (_gradeCtrls.containsKey(k)) {
            _gradeCtrls[k]!.text = v > 0 ? v.toString() : '';
          }
        }
      }

      if (_products.isNotEmpty) {
        final prodId = t.productId ??
            t['productId'] ??
            t.productId ??
            t['idProduto'] ??
            null;
        final prodName = t.productName ??
            t['productName'] ??
            t.modelo ??
            t['modelo'] ??
            null;
        ProductModel? found;
        if (prodId != null) {
          found = _products.firstWhere((p) => p.id == prodId.toString(),
              orElse: () => _products.first);
        } else if (prodName != null) {
          found = _products.firstWhere((p) => p.name == prodName.toString(),
              orElse: () => _products.first);
        }
        if (found != null) {
          setState(() => _selected = found);
        }
      }
    } catch (_) {
      // Não fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _selected != null && totalPares > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Ficha' : 'Gerar Nova Ficha'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<ProductModel>(
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
                      onPressed:
                          isReady && !_isLoading ? _onSaveTicketOnly : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(
                        _isLoading
                            ? 'Salvando...'
                            : (_isEditing
                                ? 'Salvar Alterações'
                                : 'Salvar Ficha'),
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
