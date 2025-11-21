import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/product_model.dart';
import 'product_form_page.dart';

class ProductListPage extends StatefulWidget {
  final AppUserModel user;
  const ProductListPage({super.key, required this.user});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late final CollectionReference _productsCollection;

  // --- ADIÇÕES PARA A PESQUISA ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ProductModel> _allProducts = []; // Guarda a lista completa do stream
  // --- FIM DAS ADIÇÕES ---

  @override
  void initState() {
    super.initState();
    _productsCollection = FirebaseFirestore.instance.collection('products');

    // --- ADIÇÃO: Listener para a barra de pesquisa ---
    // Atualiza a tela sempre que o usuário digitar algo
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

  Future<void> _navigateToAddProduct() async {
    await Navigator.of(context).push<ProductModel>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(user: widget.user),
      ),
    );
  }

  Future<void> _navigateToEditProduct(ProductModel product) async {
    await Navigator.of(context).push<ProductModel>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(product: product, user: widget.user),
      ),
    );
  }

  Future<void> _confirmAndDeleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja excluir o produto "${product.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _productsCollection.doc(product.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produto "${product.name}" excluído.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos Cadastrados'),
      ),
      // --- O BODY FOI REFEITO COM UMA COLUNA ---
      body: Column(
        children: [
          // 1. A BARRA DE PESQUISA
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar por Nome, Marca, Ref. ou Cor',
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
          // 2. A LISTA DE PRODUTOS (EXPANDIDA)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productsCollection
                  .where('teamId', isEqualTo: widget.user.teamId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro ao carregar produtos: ${snapshot.error}'),
                  );
                }

                // Popula a lista completa
                final productDocs = snapshot.data?.docs ?? [];
                _allProducts = productDocs
                    .map((d) => ProductModel.fromFirestore(d))
                    .toList();

                // --- LÓGICA DE FILTRO ---
                final query = _searchQuery.toLowerCase().trim();
                final filteredProducts = query.isEmpty
                    ? _allProducts // Mostra todos se a busca está vazia
                    : _allProducts.where((p) {
                        // Define quais campos pesquisar
                        return p.name.toLowerCase().contains(query) ||
                            p.brand.toLowerCase().contains(query) ||
                            p.reference.toLowerCase().contains(query) ||
                            p.color.toLowerCase().contains(query);
                      }).toList();
                // --- FIM DA LÓGICA DE FILTRO ---

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Text(
                      _allProducts.isEmpty
                          ? 'Nenhum produto cadastrado.\nUse o botão + para adicionar.'
                          : 'Nenhum resultado para "$_searchQuery".', // Mensagem de busca vazia
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Usa a lista filtrada
                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    return ListTile(
                      title: Text(
                          '${product.name} (${product.brand.isNotEmpty ? product.brand : 'Sem Marca'})'),
                      subtitle: Text(
                          'Ref: ${product.reference}  |  Cor: ${product.color}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Editar Produto',
                            onPressed: () => _navigateToEditProduct(product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Excluir Produto',
                            onPressed: () => _confirmAndDeleteProduct(product),
                          ),
                        ],
                      ),
                      onTap: () => _navigateToEditProduct(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // --- FIM DA MUDANÇA DO BODY ---
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddProduct,
        tooltip: 'Adicionar Novo Produto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
