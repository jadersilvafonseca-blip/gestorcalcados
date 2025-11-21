import 'package:flutter/material.dart';
// --- NOVOS IMPORTS DO FIREBASE ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/product_model.dart';

// --- MUDANÇA: IMPORTA O NOVO MODELO DE MATERIAL (FIREBASE) ---
import 'package:gestor_calcados_new/models/material_model.dart';
// ---------------------------------

import 'package:gestor_calcados_new/services/material_repository.dart';

class ProductFormPage extends StatefulWidget {
  final ProductModel? product;
  final AppUserModel user;
  const ProductFormPage({super.key, this.product, required this.user});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _refCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  // FocusNode para colocar foco automático após limpar
  final FocusNode _refFocus = FocusNode();

  final List<Piece> _pieces = [];

  final _materialRepo = MaterialRepository();

  // Cache de materiais (para substituir a leitura síncrona do Hive)
  List<MaterialModel> _allMaterials = [];

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isPreparing = true; // Novo estado de loading para o _prepare

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    _prepare();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _colorCtrl.dispose();
    _refFocus.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      _allMaterials = await _materialRepo.getAll(widget.user.teamId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao carregar materiais: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }

    if (_isEditing) {
      final p = widget.product!;
      _refCtrl.text = p.reference;
      _nameCtrl.text = p.name;
      _brandCtrl.text = p.brand;
      _colorCtrl.text = p.color;
      _pieces.addAll(p.pieces);
    }

    if (mounted) {
      setState(() {
        _isPreparing = false; // Termina o loading
      });
    }
  }

  void _addPieceDialog() async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    MaterialModel? selectedMaterial;
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
                        final MaterialModel? result =
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
        material: selectedMaterial!.name, // Salva o NOME do material
        color: selectedColor!,
        areaPerPair: area,
      ));
    });
  }

  Future<void> _editPieceDialog(int index) async {
    final Piece pieceToEdit = _pieces[index];

    final nameCtrl = TextEditingController(text: pieceToEdit.name);
    final areaCtrl =
        TextEditingController(text: pieceToEdit.areaPerPair.toString());

    MaterialModel? selectedMaterial;
    String? selectedColor;

    try {
      selectedMaterial = _allMaterials.firstWhere((m) =>
          m.name.toLowerCase().trim() ==
          pieceToEdit.material.toLowerCase().trim());

      if (selectedMaterial.colors.contains(pieceToEdit.color)) {
        selectedColor = pieceToEdit.color;
      }
    } catch (e) {
      selectedMaterial = null;
      selectedColor = null;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Editar peça'),
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
                        final MaterialModel? result =
                            await _selectMaterialDialog(context);
                        if (result != null) {
                          setStateInDialog(() {
                            if (selectedMaterial?.id != result.id) {
                              selectedColor = null;
                            }
                            selectedMaterial = result;
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
                    child: const Text('Salvar Alterações')),
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
      _pieces[index] = Piece(
        name: name,
        material: selectedMaterial!.name,
        color: selectedColor!,
        areaPerPair: area,
      );
    });
  }

  Future<MaterialModel?> _selectMaterialDialog(BuildContext context) async {
    final materials = _allMaterials;
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhum material cadastrado. Vá ao menu para cadastrar.'),
        backgroundColor: Colors.orange,
      ));
      return null;
    }
    return showDialog<MaterialModel>(
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

  // --- FUNÇÃO _save() (versão robusta de limpeza e foco) ---
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final reference = _refCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final brand = _brandCtrl.text.trim();
    final color = _colorCtrl.text.trim();
    final teamId = widget.user.teamId;

    try {
      ProductModel productToSave;
      final collectionRef = FirebaseFirestore.instance.collection('products');

      if (_isEditing) {
        // Modo edição: atualiza e fecha a página retornando o produto
        productToSave = ProductModel(
          id: widget.product!.id,
          teamId: widget.product!.teamId,
          reference: reference,
          name: name,
          brand: brand,
          color: color,
          pieces: _pieces,
          createdAt: widget.product!.createdAt,
        );

        await collectionRef
            .doc(productToSave.id)
            .update(productToSave.toFirestore());

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Produto atualizado.')));
        Navigator.pop(context, productToSave);
      } else {
        // Modo criação: verifica duplicidade, salva, limpa o formulário e permanece na tela
        final query = await collectionRef
            .where('teamId', isEqualTo: teamId)
            .where('reference', isEqualTo: reference)
            .where('color', isEqualTo: color)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Erro: Já existe um produto com esta Referência e Cor.'),
            backgroundColor: Colors.red,
          ));
          setState(() => _isLoading = false);
          return;
        }

        final newDocRef = collectionRef.doc();

        productToSave = ProductModel(
          id: newDocRef.id,
          teamId: teamId,
          reference: reference,
          name: name,
          brand: brand,
          color: color,
          pieces: _pieces,
          createdAt: Timestamp.now(),
        );

        await newDocRef.set(productToSave.toFirestore());

        if (!mounted) return;
        // Mensagem e limpeza do formulário para criar outro
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto cadastrado com sucesso.')),
        );

        // LIMPEZA ROBUSTA: reseta controllers, lista e form
        setState(() {
          _refCtrl.clear();
          _nameCtrl.clear();
          _brandCtrl.clear();
          _colorCtrl.clear();
          _pieces.clear();
          _formKey.currentState?.reset();
        });

        // Pequena espera para garantir que o rebuild já ocorreu antes de requisitar foco.
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_refFocus);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao salvar no Firestore: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                          controller: _refCtrl,
                          focusNode: _refFocus,
                          readOnly: _isEditing,
                          decoration: InputDecoration(
                              labelText: 'Referência (Modelo)',
                              helperText: _isEditing
                                  ? 'Não pode ser alterado na edição'
                                  : null),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Obrigatório' : null),
                      TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Nome do produto'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Obrigatório' : null),
                      TextFormField(
                          controller: _brandCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Marca')),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _colorCtrl,
                          readOnly: _isEditing,
                          decoration: InputDecoration(
                              labelText: 'Cor do Produto (Ex: Preto)',
                              helperText: _isEditing
                                  ? 'Não pode ser alterado na edição'
                                  : null),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Cor é obrigatória'
                              : null),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _pieces.isEmpty
                            ? const Center(
                                child: Text(
                                    'Nenhuma peça adicionada. Use o + no topo.'))
                            : ListView.builder(
                                itemCount: _pieces.length,
                                itemBuilder: (ctx, i) {
                                  final p = _pieces[i];
                                  MaterialModel? material;
                                  try {
                                    material = _allMaterials.firstWhere((m) =>
                                        m.name.toLowerCase().trim() ==
                                        p.material.toLowerCase().trim());
                                  } catch (e) {
                                    material = null;
                                  }
                                  final height = material?.height ?? 1.4;
                                  final pairsPerMeter = (p.areaPerPair > 0)
                                      ? (height / p.areaPerPair)
                                          .toStringAsFixed(1)
                                      : '0';
                                  final subtitleText =
                                      'Área: ${p.areaPerPair} m²  |  Pares/metro: ~$pairsPerMeter (com ${height}m)';

                                  return ListTile(
                                    isThreeLine: true,
                                    title: Text(
                                        '${p.name} — ${p.material} (${p.color.isNotEmpty ? p.color : 'N/A'})'),
                                    subtitle: Text(subtitleText),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                          onPressed: () {
                                            _editPieceDialog(i);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                    'Confirmar Exclusão'),
                                                content: Text(
                                                    'Tem certeza que quer remover a peça "${p.name}"?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child:
                                                        const Text('Cancelar'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      setState(() =>
                                                          _pieces.removeAt(i));
                                                    },
                                                    child:
                                                        const Text('Excluir'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: _isLoading ? null : _save,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_isEditing
                                  ? 'Atualizar produto'
                                  : 'Salvar produto'),
                        ),
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
