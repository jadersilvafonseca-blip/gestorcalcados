// lib/data/product_repository.dart
import 'package:hive/hive.dart';
import 'package:gestor_calcados_new/models/product.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';

const String kProductsBox = 'products_box';

class ProductRepository {
  Future<void> init() async {
    await HiveService.init();
    if (!Hive.isBoxOpen(kProductsBox)) await Hive.openBox(kProductsBox);
  }

  Box get _box => Hive.box(kProductsBox);

  List<Product> getAll() {
    final raw = _box.values.toList();
    return raw
        .map((e) {
          if (e is Product) return e;
          if (e is Map) return Product.fromMap(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<Product>()
        .toList();
  }

  Future<void> save(Product p) async {
    // se existir ID igual, sobrescreve; senão adiciona
    // vamos usar id como chave para facilitar busca
    await _box.put(p.id, p.toMap());
  }

  Product? byId(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    if (raw is Product) return raw;
    if (raw is Map) return Product.fromMap(Map<String, dynamic>.from(raw));
    return null;
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  Product? getByName(String modelo) {
    return null;
  }
}
