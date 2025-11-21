import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// --- NOVOS IMPORTS DO FIREBASE ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/material_model.dart';
// ---------------------------------

// --- IMPORTS ANTIGOS REMOVIDOS ---
// import '../services/material_repository.dart'; // Removido (usamos Firestore)
// import '../models/material_item.dart'; // Removido (usamos material_model.dart)
// ---------------------------------

class MaterialFormPage extends StatefulWidget {
  // --- MUDANÇA: Recebe o novo modelo e o usuário ---
  final MaterialModel? material;
  final AppUserModel user;

  const MaterialFormPage({super.key, this.material, required this.user});
  // --- FIM DA MUDANÇA ---

  @override
  State<MaterialFormPage> createState() => _MaterialFormPageState();
}

class _MaterialFormPageState extends State<MaterialFormPage> {
  // --- MUDANÇA: Remove o repositório do Hive ---
  // late MaterialRepository _repository;
  // --- FIM DA MUDANÇA ---
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
// Não precisamos mais carregar o Hive

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    // --- MUDANÇA: Remove a inicialização do Hive ---
    // _repository = MaterialRepository();
    // await _repository.init();
    // --- FIM DA MUDANÇA ---

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
      _colorsList.addAll(widget.material!.colors);
    }

    // Não precisamos mais do _isPageReady, mas mantemos a lógica
  }

  @override
  void dispose() {
    _nameController.dispose();
    _supplierController.dispose();
    _priceController.dispose();
    _heightController.dispose();
    _colorInputController.dispose();
    _nameFocusNode.dispose();
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

  // --- MUDANÇA: Função _saveMaterial() reescrita para o Firestore ---
  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;

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
      final teamId = widget.user.teamId;

      // ATENÇÃO AQUI: O nome da coleção é 'materials'
      // Verifique se é o mesmo nome que você usou para criar o índice de leitura
      final collectionRef = FirebaseFirestore.instance.collection('materials');

      if (_isEditing) {
        // --- MODO EDIÇÃO ---
        final material = widget.material!;

        // Novo MaterialModel com os dados atualizados
        final updatedMaterial = MaterialModel(
          id: material.id, // ID original do documento
          teamId: material.teamId, // teamId original
          name: name,
          supplier: supplier,
          price: price,
          height: height,
          colors: _colorsList,
          createdAt: material.createdAt, // Mantém data de criação
        );

        await collectionRef
            .doc(updatedMaterial.id)
            .update(updatedMaterial.toFirestore());

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
        // --- MODO CRIAÇÃO ---

        // 1. Verifica se já existe um material com este NOME e TEAMID
        // !! ISTO VAI EXIGIR UM NOVO ÍNDICE COMPOSTO NO FIREBASE !!
        // Coleção: 'materials', Campo 1: 'teamId' (Crescente), Campo 2: 'name' (Crescente)
        final query = await collectionRef
            .where('teamId', isEqualTo: teamId)
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro: Já existe um material com esse nome.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // 2. Cria o novo material
          final newDocRef = collectionRef.doc();
          final newMaterial = MaterialModel(
            id: newDocRef.id,
            teamId: teamId,
            name: name,
            supplier: supplier,
            price: price,
            height: height,
            colors: _colorsList,
            createdAt: Timestamp.now(),
          );

          await newDocRef.set(newMaterial.toFirestore());

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Material salvo! Pronto para o próximo.'),
                backgroundColor: Colors.green,
              ),
            );
            _resetForm(); // Limpa o formulário para o próximo
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Este é o 'catch' que você adicionou!
        print('DEBUG: ERRO CRÍTICO AO SALVAR: $e'); // Para o console
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
  // --- FIM DA MUDANÇA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Material' : 'Cadastrar Material'),
      ),
      // --- MUDANÇA: Removido o _isPageReady (não é mais necessário) ---
      body: SingleChildScrollView(
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
                // --- MUDANÇA: Agora o nome PODE ser editado ---
                // readOnly: _isEditing, // Removido
                // --- FIM DA MUDANÇA ---
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null; // Opcional
                        }
                        final price =
                            double.tryParse(value.replaceAll(',', '.')) ?? -1;
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Obrigatório';
                        }
                        final height =
                            double.tryParse(value.replaceAll(',', '.')) ?? 0;
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
