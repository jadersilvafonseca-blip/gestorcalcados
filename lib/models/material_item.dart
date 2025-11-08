// lib/models/material_item.dart
import 'package:hive/hive.dart';

part 'material_item.g.dart';

@HiveType(typeId: 3)
class MaterialItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  // Inicializa com lista vazia para evitar null
  @HiveField(2)
  List<String> colors;

  @HiveField(3)
  String supplier;

  @HiveField(4)
  double price;

  @HiveField(5)
  double height;

  MaterialItem({
    required this.name,
    String? id,
    List<String>? colors,
    this.supplier = '',
    double? price,
    double? height,
  })  : id = id ?? name.toLowerCase().trim(),
        colors = colors ?? [],
        price = price ?? 0.0,
        height = height ?? 1.4;

  // Atualiza campos a partir de outro MaterialItem (útil para edição)
  void updateFrom(MaterialItem other) {
    name = other.name;
    supplier = other.supplier;
    price = other.price;
    height = other.height;
    colors = List<String>.from(other.colors);
  }

  @override
  String toString() {
    return 'MaterialItem(id: $id, name: $name, colors: $colors, supplier: $supplier, price: $price, height: $height)';
  }
}
