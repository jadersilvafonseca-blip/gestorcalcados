import 'package:hive/hive.dart';
import '../models/material_item.dart';

const String kMaterialsBox = 'materials_box';

class MaterialRepository {
  late Box<MaterialItem> _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(MaterialItemAdapter().typeId)) {
      Hive.registerAdapter(MaterialItemAdapter());
    }
    _box = await Hive.openBox<MaterialItem>(kMaterialsBox);
  }

  Future<void> saveMaterial(MaterialItem material) async {
    await _box.put(material.id, material);
  }

  MaterialItem? getById(String id) {
    return _box.get(id);
  }

  List<MaterialItem> getAll() {
    final materials = _box.values.toList();
    // --- CORREÇÃO AQUI ---
    // Trocamos 'displayName' por 'name'
    materials.sort((a, b) => a.name.compareTo(b.name));
    // --- FIM DA CORREÇÃO ---
    return materials;
  }

  Future<void> deleteById(String id) async {
    await _box.delete(id);
  }

  Box<MaterialItem> getBox() {
    return _box;
  }
}
