// lib/data/product_repository.dart
import 'package:hive/hive.dart';
import 'package:gestor_calcados_new/models/product.dart';
// import 'package:gestor_calcados_new/services/hive_service.dart'; // Removido - A inicialização do Hive deve ser feita no main.dart ou Dashboard

const String kProductsBox = 'products_box';

class ProductRepository {
  // --- INÍCIO DA CORREÇÃO 1: Singleton ---
  // (Garante que o app inteiro use a mesma instância e previne erros de "box não aberta")
  static final ProductRepository _instance = ProductRepository._internal();
  factory ProductRepository() {
    return _instance;
  }
  ProductRepository._internal();

  bool _isInitialized = false;
  // --- FIM DA CORREÇÃO 1 ---

  late Box _box; // Alterado para 'late'

  Future<void> init() async {
    // Se já foi inicializado pelo Dashboard ou outro local, não faz nada
    if (_isInitialized) return;

    // Removida a chamada ao HiveService.init() daqui
    if (!Hive.isBoxOpen(kProductsBox)) {
      _box = await Hive.openBox(kProductsBox); // Atribui a box
    } else {
      _box = Hive.box(kProductsBox); // Apenas pega a referência
    }
    _isInitialized = true;
  }

  // Box get _box => Hive.box(kProductsBox); // Removido, _box agora é um campo

  List<Product> getAll() {
    final raw = _box.values.toList();
    return raw
        .map((e) {
          if (e is Product) return e; // (Isso provavelmente nunca acontece)
          if (e is Map) return Product.fromMap(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<Product>()
        .toList();
  }

  Future<void> save(Product p) async {
    // Esta lógica está CORRETA.
    // Ela usa o 'p.id' (que agora é "ref-cor") como chave.
    await _box.put(p.id, p.toMap());
  }

  // --- INÍCIO DA CORREÇÃO 2: getById ---
  // (Renomeado de 'byId' e implementado corretamente)
  Product? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    if (raw is Product) return raw; // (Legacy)
    if (raw is Map) return Product.fromMap(Map<String, dynamic>.from(raw));
    return null;
  }
  // --- FIM DA CORREÇÃO 2 ---

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  // --- INÍCIO DA CORREÇÃO 3: getByName ---
  // (Implementado para buscar pelo NOME do produto, que o Ticket usa como 'modelo')
  Product? getByName(String modelo) {
    // Itera por todos os produtos salvos
    for (final product in getAll()) {
      if (product.name == modelo) {
        return product;
      }
    }
    return null; // Não encontrou
  }
  // --- FIM DA CORREÇÃO 3 ---

  // (A função 'byId' e a 'getById' vazia foram removidas)
}
