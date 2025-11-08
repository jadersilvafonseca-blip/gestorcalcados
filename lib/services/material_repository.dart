// lib/services/material_repository.dart
import 'package:hive/hive.dart';

// --- CORREÇÃO FINAL: Usamos o caminho de pacote (package:) ---
// O Dart agora buscará o arquivo gerado a partir da raiz 'lib/'
import 'package:gestor_calcados_new/models/material_item.dart';
// ------------------------------------------------------------

const String kMaterialsBox = 'materials_box';

class MaterialRepository {
  // --- Singleton (CORRETO) ---
  static final MaterialRepository _instance = MaterialRepository._internal();
  factory MaterialRepository() {
    return _instance;
  }
  MaterialRepository._internal();

  late Box<MaterialItem> _box;
  bool _isInitialized = false;

  // --- O REGISTRO DO ADAPTADOR ACONTECE AQUI ---
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. REGISTRA O ADAPTADOR
    if (!Hive.isAdapterRegistered(MaterialItemAdapter().typeId)) {
      Hive.registerAdapter(MaterialItemAdapter());
    }

    // 2. Abre a caixa
    _box = await Hive.openBox<MaterialItem>(kMaterialsBox);

    _isInitialized = true;
  }

  Future<void> saveMaterial(MaterialItem material) async {
    if (!_isInitialized) await init();

    // Garante lista não-nula
    material.colors = material.colors;

    await _box.put(material.id, material);
  }

  MaterialItem? getById(String id) {
    return _box.get(id);
  }

  List<MaterialItem> getAll() {
    final materials = _box.values.toList();
    materials.sort((a, b) => a.name.compareTo(b.name));
    return materials;
  }

  Future<void> deleteById(String id) async {
    await _box.delete(id);
  }

  Box<MaterialItem> getBox() {
    return _box;
  }
}
