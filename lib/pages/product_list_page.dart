// lib/pages/product_list_page.dart
import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/data/product_repository.dart';
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'product_form_page.dart'; // Importa a página de formulário

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final repo = ProductRepository();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    // Garante que o Hive e o repositório estejam prontos
    await HiveService.init();
    await repo.init();
    setState(() {
      _products = repo.getAll();
      _isLoading = false;
    });
  }

  // Navega para a tela de formulário para ADICIONAR um novo produto
  Future<void> _navigateToAddProduct() async {
    final result = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => const ProductFormPage(), // Sem passar produto
      ),
    );

    // Se um produto foi salvo e retornado, atualiza a lista
    if (result != null && mounted) {
      _loadProducts(); // Recarrega a lista para mostrar o novo produto
    }
  }

  // Navega para a tela de formulário para EDITAR um produto existente
  Future<void> _navigateToEditProduct(Product product) async {
    final result = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(product: product), // Passa o produto
      ),
    );

    // Se um produto foi salvo e retornado, atualiza a lista
    if (result != null && mounted) {
      _loadProducts(); // Recarrega a lista para mostrar as alterações
    }
  }

  // Mostra um diálogo de confirmação antes de excluir
  Future<void> _confirmAndDeleteProduct(Product product) async {
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
      await repo.delete(product.id); // Deleta do repositório
      _loadProducts(); // Recarrega a lista
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produto "${product.name}" excluído.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos Cadastrados'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum produto cadastrado.\nUse o botão + para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ListTile(
                      title: Text('${product.name} (${product.brand})'),
                      subtitle: Text('Ref: ${product.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize
                            .min, // Impede a Row de ocupar toda a largura
                        children: [
                          // Botão Editar
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Editar Produto',
                            onPressed: () => _navigateToEditProduct(product),
                          ),
                          // Botão Excluir
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Excluir Produto',
                            onPressed: () => _confirmAndDeleteProduct(product),
                          ),
                        ],
                      ),
                      // Você pode adicionar um onTap no ListTile se quiser
                      // que clicar no item também abra a edição, por exemplo:
                      // onTap: () => _navigateToEditProduct(product),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddProduct,
        tooltip: 'Adicionar Novo Produto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
