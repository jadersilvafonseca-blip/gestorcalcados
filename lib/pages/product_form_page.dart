// lib/pages/product_form_page.dart
import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/data/product_repository.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'package:gestor_calcados_new/models/material_item.dart';
import 'package:gestor_calcados_new/services/material_repository.dart';

// ignore: unused_import
import 'package:gestor_calcados_new/utils/date.dart';

class ProductFormPage extends StatefulWidget {
  final Product? product;

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  // --- MUDANÇA: _idCtrl virou _refCtrl (para "Referência") ---
  final _refCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  final List<Piece> _pieces = [];

  final repo = ProductRepository();
  final _materialRepo = MaterialRepository();

  // --- NOVO: Flag para modo de edição ---
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null; // Define o modo
    _prepare();
  }

  Future<void> _prepare() async {
    await HiveService.init();
    await repo.init();
    await _materialRepo.init();

    if (_isEditing) {
      // Usa a flag
      final p = widget.product!;
      // --- MUDANÇA: Preenche os campos corretos ---
      _refCtrl.text = p.reference; // <--- O campo de referência
      _nameCtrl.text = p.name;
      _brandCtrl.text = p.brand;
      _colorCtrl.text = p.color;
      _pieces.addAll(p.pieces);
      if (mounted) {
        setState(() {});
      }
    }
  }

  // --- O _addPieceDialog() e o _selectMaterialDialog() estão CORRETOS ---
  // (Nenhuma alteração aqui, estão perfeitos como você mandou)
  void _addPieceDialog() async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    MaterialItem? selectedMaterial;
    String? selectedColor;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Adicionar peça'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nome da peça'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Material'),
                      subtitle: Text(
                        selectedMaterial?.name ?? 'Clique para selecionar',
                        style: TextStyle(
                          color: selectedMaterial != null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          fontWeight: selectedMaterial != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final MaterialItem? result =
                            await _selectMaterialDialog(context);
                        if (result != null) {
                          setStateInDialog(() {
                            selectedMaterial = result;
                            selectedColor = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    if (selectedMaterial != null)
                      DropdownButtonFormField<String>(
                        value: selectedColor,
                        hint: const Text('Selecione uma cor'),
                        decoration: const InputDecoration(
                          labelText: 'Cor',
                          border: OutlineInputBorder(),
                        ),
                        items: selectedMaterial!.colors
                            .map((color) => DropdownMenuItem(
                                  value: color,
                                  child: Text(color),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setStateInDialog(() {
                            selectedColor = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Obrigatório' : null,
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: areaCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Área por par (m²) - ex: 0.0198'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
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
            );
          },
        );
      },
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final area = double.tryParse(areaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (name.isEmpty ||
        selectedMaterial == null ||
        selectedColor == null ||
        area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preencha nome, área, material e cor válidos.'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() {
      _pieces.add(Piece(
        name: name,
        material: selectedMaterial!.name,
        color: selectedColor!,
        areaPerPair: area,
      ));
    });
  }

  Future<MaterialItem?> _selectMaterialDialog(BuildContext context) async {
    final materials = _materialRepo.getAll();
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhum material cadastrado. Vá ao menu para cadastrar.'),
        backgroundColor: Colors.orange,
      ));
      return null;
    }
    return showDialog<MaterialItem>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Selecione um Material'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index];
                final priceString =
                    'R\$ ${material.price.toStringAsFixed(2).replaceAll('.', ',')}';
                final heightString =
                    '${material.height.toStringAsFixed(2).replaceAll('.', ',')}m';
                return ListTile(
                  title: Text(material.name),
                  subtitle: Text('Altura: $heightString - Preço: $priceString'),
                  onTap: () {
                    Navigator.pop(ctx, material);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }
  // --- FIM DAS FUNÇÕES NÃO ALTERADAS ---

  // --- FUNÇÃO _save() TOTALMENTE ATUALIZADA ---
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Pega os valores dos campos
    final reference = _refCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final brand = _brandCtrl.text.trim();
    final color = _colorCtrl.text.trim();

    double heightToSave = 1.4;
    Product productToSave; // Declara o produto

    if (_isEditing) {
      // --- MODO EDIÇÃO ---
      // Apenas atualiza os campos. O ID (ref+cor) não pode mudar.
      heightToSave = widget.product!.materialHeightMeters;
      productToSave = Product(
        reference: reference, // 'reference' e 'color' são dos campos (readOnly)
        name: name,
        brand: brand,
        color: color,
        pieces: List<Piece>.from(_pieces),
        materialHeightMeters: heightToSave,
      );
      // O ID gerado no construtor será o mesmo, pois 'reference' e 'color'
      // não mudaram, permitindo ao Hive sobrescrever (atualizar) o item.
    } else {
      // --- MODO CRIAÇÃO ---

      // 2. Gera o ID único (ref + cor)
      final uniqueId =
          '${reference.toLowerCase().trim()}-${color.toLowerCase().trim()}';

      // 3. Verifica se esse ID (Ref+Cor) já existe
      // (Requer que 'repo' tenha o método 'getById')
      final existingProduct = repo.getById(uniqueId);

      if (existingProduct != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Erro: Já existe um produto com esta Referência e Cor.'),
          backgroundColor: Colors.red,
        ));
        return; // Para o salvamento
      }

      // 4. Se não existe, cria o novo produto
      productToSave = Product(
        reference: reference,
        name: name,
        brand: brand,
        color: color,
        pieces: List<Piece>.from(_pieces),
        materialHeightMeters: heightToSave, // Usa o padrão 1.4
      );
    }

    // 5. Salva (funciona para criar ou atualizar)
    // O 'repo.save' deve usar o 'productToSave.id' como chave
    await repo.save(productToSave);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Produto salvo.')));
    Navigator.pop(context, productToSave); // Retorna o produto salvo
  }
  // --- FIM DA FUNÇÃO _save() ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar produto' : 'Novo produto'),
        actions: [
          IconButton(onPressed: _addPieceDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // --- CAMPO REFERÊNCIA ATUALIZADO ---
                TextFormField(
                    controller: _refCtrl, // <-- MUDOU AQUI
                    // Bloqueia se estiver editando (para não mudar a chave)
                    readOnly: _isEditing,
                    decoration: InputDecoration(
                        labelText: 'Referência (Modelo)',
                        // Mostra aviso se estiver editando
                        helperText: _isEditing
                            ? 'Não pode ser alterado na edição'
                            : null),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Obrigatório' : null),
                // --- FIM DA MUDANÇA ---

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

                // --- CAMPO COR ATUALIZADO ---
                TextFormField(
                    controller: _colorCtrl,
                    // Bloqueia se estiver editando (para não mudar a chave)
                    readOnly: _isEditing,
                    decoration: InputDecoration(
                        labelText: 'Cor do Produto (Ex: Preto)',
                        // Mostra aviso se estiver editando
                        helperText: _isEditing
                            ? 'Não pode ser alterado na edição'
                            : null),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Cor é obrigatória' : null),
                // --- FIM DA MUDANÇA ---

                const SizedBox(height: 12),

                // --- LISTVIEW DE PEÇAS (Sem alteração) ---
                Expanded(
                  child: _pieces.isEmpty
                      ? const Center(
                          child:
                              Text('Nenhuma peça adicionada. Use o + no topo.'))
                      : ListView.builder(
                          itemCount: _pieces.length,
                          itemBuilder: (ctx, i) {
                            final p = _pieces[i];
                            final material = _materialRepo
                                .getById(p.material.toLowerCase().trim());
                            final height = material?.height ?? 1.4;
                            final pairsPerMeter = (p.areaPerPair > 0)
                                ? (height / p.areaPerPair).toStringAsFixed(1)
                                : '0';
                            final subtitleText =
                                'Área: ${p.areaPerPair} m²  |  Pares/metro: ~$pairsPerMeter (com ${height}m)';

                            return ListTile(
                              isThreeLine: true,
                              title: Text(
                                  '${p.name} — ${p.material} (${p.color.isNotEmpty ? p.color : 'N/A'})'),
                              subtitle: Text(subtitleText),
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
    );
  }
}
