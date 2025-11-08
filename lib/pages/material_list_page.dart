// lib/screens/material_list_page.dart
import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/models/material_item.dart';
import 'package:gestor_calcados_new/services/material_repository.dart'; // caminho corrigido
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'material_form_page.dart';

class MaterialListPage extends StatefulWidget {
  const MaterialListPage({super.key});

  @override
  State<MaterialListPage> createState() => _MaterialListPageState();
}

class _MaterialListPageState extends State<MaterialListPage> {
  final MaterialRepository _repository = MaterialRepository();
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _repository.init();
  }

  void _navigateToForm(MaterialItem? material) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => MaterialFormPage(material: material),
      ),
    )
        .then((_) {
      // força reconstrução quando voltar (ValueListenableBuilder atualiza a lista também)
      if (mounted) setState(() {});
    });
  }

  void _confirmDelete(MaterialItem material) {
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

  Future<void> _deleteMaterial(MaterialItem material) async {
    try {
      await _repository.deleteById(material.id);

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
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar materiais: ${snapshot.error}'),
            );
          }

          // Garantimos que a inicialização já terminou com sucesso
          final Box<MaterialItem> box = _repository.getBox();

          return ValueListenableBuilder<Box<MaterialItem>>(
            valueListenable: box.listenable(),
            builder: (context, boxSnapshot, _) {
              final materials = boxSnapshot.values.toList()
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (materials.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum material cadastrado ainda.\nClique no "+" para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: materials.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final material = materials[index];

                  // Segurança: trate colors possivelmente nulas (caso algum dado legado exista)
                  final colorsList = (material.colors);
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
          );
        },
      ),
    );
  }
}
