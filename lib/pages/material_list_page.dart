import 'package:flutter/material.dart';
// --- NOVOS IMPORTS DO FIREBASE ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/material_model.dart'; // O nosso novo modelo
// ---------------------------------

import 'material_form_page.dart';

class MaterialListPage extends StatefulWidget {
  // --- MUDANÇA: Recebe o usuário (para sabermos o teamId) ---
  final AppUserModel user;
  const MaterialListPage({super.key, required this.user});
  // --- FIM DA MUDANÇA ---

  @override
  State<MaterialListPage> createState() => _MaterialListPageState();
}

class _MaterialListPageState extends State<MaterialListPage> {
  late final CollectionReference _materialsCollection;

  // --- ADIÇÕES PARA A PESQUISA ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<MaterialModel> _allMaterials = []; // Guarda a lista completa do stream
  // --- FIM DAS ADIÇÕES ---

  @override
  void initState() {
    super.initState();
    // Aponta para a coleção 'materials'
    _materialsCollection = FirebaseFirestore.instance.collection('materials');

    // --- ADIÇÃO: Listener para a barra de pesquisa ---
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    // --- FIM DA ADIÇÃO ---
  }

  // --- ADIÇÃO: Dispose do controller ---
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // --- FIM DA ADIÇÃO ---

  void _navigateToForm(MaterialModel? material) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => MaterialFormPage(material: material, user: widget.user),
      ),
    )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _confirmDelete(MaterialModel material) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir "${material.name}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteMaterial(material);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaterial(MaterialModel material) async {
    try {
      await _materialsCollection.doc(material.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${material.name}" foi excluído.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiais Cadastrados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(null),
          ),
        ],
      ),
      // --- MUDANÇA: O body agora é uma Column ---
      body: Column(
        children: [
          // 1. A BARRA DE PESQUISA
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar por Nome ou Cor',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // 2. A LISTA (EXPANDIDA)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _materialsCollection
                  .where('teamId', isEqualTo: widget.user.teamId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Erro ao carregar materiais: ${snapshot.error}'));
                }

                // Popula a lista completa
                final materialDocs = snapshot.data?.docs ?? [];
                _allMaterials = materialDocs
                    .map((d) => MaterialModel.fromFirestore(d))
                    .toList();

                // --- LÓGICA DE FILTRO ---
                final query = _searchQuery.toLowerCase().trim();
                final filteredMaterials = query.isEmpty
                    ? _allMaterials
                    : _allMaterials.where((m) {
                        // Pesquisa no NOME
                        final nameMatch = m.name.toLowerCase().contains(query);
                        // Pesquisa na LISTA DE CORES
                        final colorMatch = m.colors.any(
                            (color) => color.toLowerCase().contains(query));
                        return nameMatch || colorMatch;
                      }).toList();
                // --- FIM DA LÓGICA DE FILTRO ---

                if (filteredMaterials.isEmpty) {
                  return Center(
                    child: Text(
                      _allMaterials.isEmpty
                          ? 'Nenhum material cadastrado ainda.\nClique no "+" para começar.'
                          : 'Nenhum resultado para "$_searchQuery".', // Mensagem de busca vazia
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Usa a lista filtrada
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredMaterials.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final material = filteredMaterials[index];

                    final colorsList = material.colors;
                    final displayColors = colorsList.take(3).toList();
                    final colorsListString = displayColors.isEmpty
                        ? 'sem cores'
                        : displayColors.join(', ');
                    final hasMoreColors = colorsList.length > 3;

                    final priceString =
                        'R\$ ${material.price.toStringAsFixed(2).replaceAll('.', ',')}';
                    final heightString =
                        '${material.height.toStringAsFixed(2).replaceAll('.', ',')}m';

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(colorsList.length.toString()),
                      ),
                      title: Text(
                        material.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Altura: $heightString - Preço: $priceString\nCores: $colorsListString${hasMoreColors ? '...' : ''}',
                      ),
                      isThreeLine: true,
                      onTap: () => _navigateToForm(material),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade700),
                        onPressed: () => _confirmDelete(material),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // --- FIM DA MUDANÇA DO BODY ---
    );
  }
}
