// lib/pages/product_form_page.dart
import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/data/product_repository.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
// ignore: unused_import
import 'package:gestor_calcados_new/utils/date.dart';

class ProductFormPage extends StatefulWidget {
  final Product? product; // se for editar

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  double _materialHeight = 1.4;

  final List<Piece> _pieces = [];

  final repo = ProductRepository();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await HiveService.init();
    await repo.init();
    if (widget.product != null) {
      final p = widget.product!;
      _idCtrl.text = p.id;
      _nameCtrl.text = p.name;
      _brandCtrl.text = p.brand;
      _materialHeight = p.materialHeightMeters;
      _pieces.addAll(p.pieces);
      setState(() {});
    }
  }

  void _addPieceDialog() async {
    final nameCtrl = TextEditingController();
    final materialCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final areaCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar peça'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome da peça')),
              TextField(
                  controller: materialCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Material (ex: curvim)')),
              TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'Cor')),
              TextField(
                  controller: areaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Área por par (m²) - ex: 0.0198'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Adicionar')),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final material = materialCtrl.text.trim();
    final color = colorCtrl.text.trim();
    final area = double.tryParse(areaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (name.isEmpty || material.isEmpty || area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preencha nome, material e área válida.')));
      return;
    }
    setState(() {
      _pieces.add(Piece(
          name: name, material: material, color: color, areaPerPair: area));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final brand = _brandCtrl.text.trim();

    final product = Product(
      id: id,
      name: name,
      brand: brand,
      pieces: List<Piece>.from(_pieces),
      materialHeightMeters: _materialHeight,
    );

    await repo.save(product);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Produto salvo.')));
    Navigator.pop(context, product);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Novo produto' : 'Editar produto'),
        actions: [
          IconButton(onPressed: _addPieceDialog, icon: const Icon(Icons.add)),
        ],
      ),
      // =========== ALTERAÇÃO AQUI ===========
      body: SafeArea(
        bottom: true, // Garante espaço na parte inferior (barra de navegação)
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                    controller: _idCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Referência (Modelo)'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Obrigatório' : null),
                TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nome do produto'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Obrigatório' : null),
                TextFormField(
                    controller: _brandCtrl,
                    decoration: const InputDecoration(labelText: 'Marca')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Altura material (m):'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _materialHeight,
                        min: 0.5,
                        max: 2.5,
                        divisions: 20,
                        label: _materialHeight.toStringAsFixed(2),
                        onChanged: (v) => setState(() => _materialHeight = v),
                      ),
                    ),
                    Text(_materialHeight.toStringAsFixed(2)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _pieces.isEmpty
                      ? const Center(
                          child:
                              Text('Nenhuma peça adicionada. Use o + no topo.'))
                      : ListView.builder(
                          itemCount: _pieces.length,
                          itemBuilder: (ctx, i) {
                            final p = _pieces[i];
                            return ListTile(
                              title: Text(
                                  '${p.name} — ${p.material} (${p.color})'),
                              subtitle: Text(
                                  'Área/par: ${p.areaPerPair} m² — pares/metro: ${(1.4 / p.areaPerPair).toStringAsFixed(2)} (ex. com 1.4m)'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    setState(() => _pieces.removeAt(i)),
                              ),
                            );
                          },
                        ),
                ),
                FilledButton.tonal(
                  onPressed: _save,
                  child: const Text('Salvar produto'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      // =========== FIM DA ALTERAÇÃO ===========
    );
  }
}
