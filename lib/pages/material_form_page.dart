// lib/screens/material_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/material_repository.dart';
import '../models/material_item.dart';

class MaterialFormPage extends StatefulWidget {
  final MaterialItem? material;
  const MaterialFormPage({super.key, this.material});

  @override
  State<MaterialFormPage> createState() => _MaterialFormPageState();
}

class _MaterialFormPageState extends State<MaterialFormPage> {
  late MaterialRepository _repository;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _supplierController;
  late TextEditingController _priceController;
  late TextEditingController _heightController;
  late TextEditingController _colorInputController;

  late FocusNode _nameFocusNode;

  final List<String> _colorsList = [];
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isPageReady = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    _repository = MaterialRepository();
    await _repository.init();

    _isEditing = widget.material != null;

    _nameController =
        TextEditingController(text: _isEditing ? widget.material!.name : '');
    _supplierController = TextEditingController(
        text: _isEditing ? widget.material!.supplier : '');
    _priceController = TextEditingController(
        text: _isEditing ? widget.material!.price.toStringAsFixed(2) : '');
    _heightController = TextEditingController(
        text: _isEditing ? widget.material!.height.toStringAsFixed(2) : '1.40');
    _colorInputController = TextEditingController();

    _nameFocusNode = FocusNode();

    if (_isEditing) {
      // carrega as cores existentes para edição
      final existing = widget.material!.colors;
      if (existing != null) _colorsList.addAll(existing);
    }

    if (mounted) {
      setState(() {
        _isPageReady = true;
      });
    }
  }

  @override
  void dispose() {
    // só dispose se os controllers foram inicializados
    if (_isPageReady) {
      _nameController.dispose();
      _supplierController.dispose();
      _priceController.dispose();
      _heightController.dispose();
      _colorInputController.dispose();
      _nameFocusNode.dispose();
    }
    super.dispose();
  }

  void _addNewColor() {
    final newColor = _colorInputController.text.trim();
    if (newColor.isEmpty) return;

    final alreadyExists =
        _colorsList.any((c) => c.toLowerCase() == newColor.toLowerCase());

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa cor já foi adicionada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _colorsList.add(newColor));
    _colorInputController.clear();
    FocusScope.of(context).unfocus();
  }

  // Limpa o formulário (apenas no modo criação)
  void _resetForm() {
    setState(() {
      _nameController.clear();
      _supplierController.clear();
      _priceController.clear();
      _heightController.text = '1.40';
      _colorsList.clear();
      _colorInputController.clear();
    });
    _nameFocusNode.requestFocus();
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;

    // No fluxo atual eu mantenho a exigência de pelo menos 1 cor.
    // Se preferir permitir 0 cores, remova esse bloco.
    if (_colorsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos uma cor para este material.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final supplier = _supplierController.text.trim();
      final price =
          double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;
      final height =
          double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 1.4;

      if (_isEditing) {
        // EDIÇÃO: atualiza o objeto existente
        final material = widget.material!;
        // name é readOnly em edição (mantido)
        material.supplier = supplier;
        material.price = price;
        material.height = height;

        // Atualiza as cores com a lista atual de chips
        material.colors = List<String>.from(_colorsList);

        await _repository.saveMaterial(material);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Material atualizado!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // CRIAÇÃO: valida duplicidade e salva novo material
        final newId = name.toLowerCase().trim();
        final existingMaterial = _repository.getById(newId);

        if (existingMaterial != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro: Já existe um material com esse nome.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          final newMaterial = MaterialItem(
            name: name,
            supplier: supplier,
            price: price,
            height: height,
            colors: List<String>.from(_colorsList),
          );

          await _repository.saveMaterial(newMaterial);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Material salvo! Pronto para o próximo.'),
                backgroundColor: Colors.green,
              ),
            );
            _resetForm();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Material' : 'Cadastrar Material'),
      ),
      body: !_isPageReady
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Material (Ex: Camurça)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_important_outline),
                      ),
                      readOnly: _isEditing,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'O nome é obrigatório';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_mall_directory_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Preço (R\$)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money_outlined),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return null; // Opcional
                              }
                              final price =
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                      -1;
                              if (price < 0) {
                                return 'Preço inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Altura (m)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.straighten_outlined),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Obrigatório';
                              }
                              final height =
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                      0;
                              if (height <= 0) {
                                return 'Inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Cores Disponíveis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _colorInputController,
                            decoration: const InputDecoration(
                              labelText: 'Digite uma cor (Ex: Preto)',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _addNewColor(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          iconSize: 30,
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: _addNewColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _colorsList.isEmpty
                          ? const Text(
                              'Nenhuma cor adicionada.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: _colorsList.map((color) {
                                return Chip(
                                  label: Text(color),
                                  backgroundColor: Colors.grey.shade200,
                                  onDeleted: () {
                                    setState(() {
                                      _colorsList.remove(color);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading
                          ? 'Salvando...'
                          : (_isEditing ? 'Atualizar' : 'Salvar')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveMaterial,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
