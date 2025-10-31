// lib/models/product.dart
import 'dart:convert';

/// Representa uma peça do calçado (uma parte que consome material)
class Piece {
  final String name; // e.g. "Frente", "Forro", "Lingueta"
  final String material; // e.g. "curvim"
  final String color; // e.g. "branco"
  final double areaPerPair; // metros por par (ex: 0.0198)

  Piece({
    required this.name,
    required this.material,
    required this.color,
    required this.areaPerPair,
  });

  /// quantos pares dá com 1,0 metro linear (altura do material deve ser considerada separadamente)
  Map<String, dynamic> toMap() => {
        'name': name,
        'material': material,
        'color': color,
        'areaPerPair': areaPerPair,
      };

  factory Piece.fromMap(Map m) => Piece(
        name: (m['name'] ?? '').toString(),
        material: (m['material'] ?? '').toString(),
        color: (m['color'] ?? '').toString(),
        areaPerPair: (m['areaPerPair'] is num)
            ? (m['areaPerPair'] as num).toDouble()
            : double.tryParse((m['areaPerPair'] ?? '0').toString()) ?? 0.0,
      );

  String toJson() => jsonEncode(toMap());
  factory Piece.fromJson(String s) =>
      Piece.fromMap(Map<String, dynamic>.from(jsonDecode(s)));
}

/// Produto (modelo) — junta várias peças
class Product {
  final String id; // ex: "P-0001" ou sku
  final String name; // ex: "Tênis XYZ"
  final String brand;
  final Map<String, dynamic> extra; // para campos livres
  final List<Piece> pieces;

  // altura útil do material (metro linear por faixa) — por padrão 1.4m como você pediu
  final double materialHeightMeters;

  Product({
    required this.id,
    required this.name,
    this.brand = '',
    this.extra = const {},
    this.pieces = const [],
    this.materialHeightMeters = 1.4,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'extra': extra,
        'materialHeightMeters': materialHeightMeters,
        'pieces': pieces.map((p) => p.toMap()).toList(),
      };

  factory Product.fromMap(Map m) => Product(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        brand: (m['brand'] ?? '').toString(),
        extra: Map<String, dynamic>.from(m['extra'] ?? {}),
        materialHeightMeters: (m['materialHeightMeters'] is num)
            ? (m['materialHeightMeters'] as num).toDouble()
            : double.tryParse(
                    (m['materialHeightMeters'] ?? '1.4').toString()) ??
                1.4,
        pieces: (m['pieces'] as List?)
                ?.map((e) => Piece.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );

  String toJson() => jsonEncode(toMap());
  factory Product.fromJson(String s) =>
      Product.fromMap(Map<String, dynamic>.from(jsonDecode(s)));

  // ---------------- cálculos ----------------

  /// retorna quantos pares são possíveis por metro linear (considerando altura do material)
  /// para uma peça específica: pairsPerMeter = materialHeightMeters / areaPerPair
  double pairsPerMeterForPiece(Piece p) {
    if (p.areaPerPair <= 0) return 0.0;
    return materialHeightMeters / p.areaPerPair;
  }

  /// dado N pares, quantos metros desse material (mesma material+cor) serão consumidos somando todas as peças deste produto
  ///
  /// Retorna um mapa:
  /// { 'material|color' : metersNeeded (double) }
  Map<String, double> materialsNeededForPairs(int pairs) {
    // soma área por material+color por par
    final Map<String, double> areaPerPairByMaterialColor = {};
    for (final p in pieces) {
      final key = '${p.material}||${p.color}';
      areaPerPairByMaterialColor.update(key, (v) => v + p.areaPerPair,
          ifAbsent: () => p.areaPerPair);
    }

    // para cada material+color calcule metros necessários:
    // meters = (areaPerPairTotal * pairs) / materialHeightMeters
    final Map<String, double> meters = {};
    areaPerPairByMaterialColor.forEach((key, areaPerPairTotal) {
      final needed = (areaPerPairTotal * pairs) / materialHeightMeters;
      meters[key] = needed;
    });
    return meters;
  }

  /// utilitário legível: retorna lista com material, color e metros (com formatação)
  List<MaterialEstimate> estimateMaterialsReadable(int pairs) {
    final m = materialsNeededForPairs(pairs);
    return m.entries.map((e) {
      final parts = e.key.split('||');
      final mat = parts[0];
      final color = parts.length > 1 ? parts[1] : '';
      return MaterialEstimate(material: mat, color: color, meters: e.value);
    }).toList();
  }
}

class MaterialEstimate {
  final String material;
  final String color;
  final double meters;
  MaterialEstimate({
    required this.material,
    required this.color,
    required this.meters,
  });
}
