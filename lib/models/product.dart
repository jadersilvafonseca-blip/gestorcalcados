// lib/models/product.dart
import 'dart:convert';
import 'package:gestor_calcados_new/services/material_repository.dart';

/// Representa uma peça do calçado (uma parte que consome material)
class Piece {
  final String name;
  final String material;
  final String color;
  final double areaPerPair;

  Piece({
    required this.name,
    required this.material,
    required this.color,
    required this.areaPerPair,
  });

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
  // --- INÍCIO DA LÓGICA ---

  // 'id' agora é a chave única gerada (ex: "ref-100-preto")
  late final String id;

  // 'reference' é o que o usuário digita (ex: "REF-100")
  final String reference;

  // --- FIM DA LÓGICA ---

  final String name; // ex: "Tênis XYZ"
  final String brand;
  final String color;
  final Map<String, dynamic> extra;
  final List<Piece> pieces;
  final double materialHeightMeters;

  Product({
    // 'id' não é mais 'required' aqui
    required this.reference, // <--- CAMPO NOVO
    required this.name,
    required this.color, // <--- 'color' agora é 'required'
    this.brand = '',
    this.extra = const {},
    this.pieces = const [],
    this.materialHeightMeters = 1.4,
  }) {
    // --- GERA O ID ÚNICO AUTOMATICAMENTE ---
    // A chave primária do produto agora é a combinação da referência + cor
    id = '${reference.toLowerCase().trim()}-${color.toLowerCase().trim()}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference, // <--- SALVA A REFERÊNCIA
        'name': name,
        'brand': brand,
        'color': color,
        'extra': extra,
        'materialHeightMeters': materialHeightMeters,
        'pieces': pieces.map((p) => p.toMap()).toList(),
      };

  factory Product.fromMap(Map m) {
    // Se 'reference' não existir (dado antigo), usa o 'id' antigo como fallback
    final ref = (m['reference'] ?? m['id'] ?? '').toString();
    final color = (m['color'] ?? '').toString();

    return Product(
      reference: ref, // <--- LÊ A REFERÊNCIA
      name: (m['name'] ?? '').toString(),
      brand: (m['brand'] ?? '').toString(),
      color: color,
      extra: Map<String, dynamic>.from(m['extra'] ?? {}),
      materialHeightMeters: (m['materialHeightMeters'] is num)
          ? (m['materialHeightMeters'] as num).toDouble()
          : double.tryParse((m['materialHeightMeters'] ?? '1.4').toString()) ??
              1.4,
      pieces: (m['pieces'] as List?)
              ?.map((e) => Piece.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
    // O 'id' será gerado automaticamente pelo construtor
  }

  String toJson() => jsonEncode(toMap());
  factory Product.fromJson(String s) =>
      Product.fromMap(Map<String, dynamic>.from(jsonDecode(s)));

  // ---------------- cálculos ----------------
  // (Nenhuma mudança no resto do arquivo)

  double pairsPerMeterForPiece(Piece p) {
    if (p.areaPerPair <= 0) return 0.0;
    return materialHeightMeters / p.areaPerPair;
  }

  Map<String, double> materialsNeededForPairs(
    int pairs,
    MaterialRepository materialRepo,
  ) {
    final Map<String, double> areaPerPairByMaterialColor = {};
    for (final p in pieces) {
      final key = '${p.material}||${p.color}';
      areaPerPairByMaterialColor.update(key, (v) => v + p.areaPerPair,
          ifAbsent: () => p.areaPerPair);
    }
    final Map<String, double> meters = {};
    areaPerPairByMaterialColor.forEach((key, areaPerPairTotal) {
      final materialName = key.split('||')[0].toLowerCase().trim();
      final materialItem = materialRepo.getById(materialName);
      final double actualHeight = materialItem?.height ?? 1.4;
      final needed = (areaPerPairTotal * pairs) / actualHeight;
      meters[key] = needed;
    });
    return meters;
  }

  List<MaterialEstimate> estimateMaterialsReadable(
    int pairs,
    MaterialRepository materialRepo,
  ) {
    final Map<String, (double, List<String>)> summary = {};
    for (final p in pieces) {
      final key = '${p.material}||${p.color}';
      final current = summary[key] ?? (0.0, <String>[]);
      final newArea = current.$1 + p.areaPerPair;
      final newPieces = List<String>.from(current.$2)..add(p.name);
      summary[key] = (newArea, newPieces);
    }
    final List<MaterialEstimate> estimates = [];
    summary.forEach((key, data) {
      final totalArea = data.$1;
      final pieceNames = data.$2..sort();
      final parts = key.split('||');
      final materialName = parts[0];
      final color = parts.length > 1 ? parts[1] : '';
      final materialItem =
          materialRepo.getById(materialName.toLowerCase().trim());
      final double actualHeight = materialItem?.height ?? 1.4;
      final neededMeters = (totalArea * pairs) / actualHeight;
      estimates.add(MaterialEstimate(
        material: materialName,
        color: color,
        meters: neededMeters,
        pieceNames: pieceNames,
      ));
    });
    return estimates;
  }
}

class MaterialEstimate {
  final String material;
  final String color;
  final double meters;
  final List<String> pieceNames;

  MaterialEstimate({
    required this.material,
    required this.color,
    required this.meters,
    this.pieceNames = const [],
  });

  Map<String, dynamic> toMap() => {
        'material': material,
        'color': color,
        'meters': meters,
        'pieceNames': pieceNames,
      };

  factory MaterialEstimate.fromMap(Map m) {
    return MaterialEstimate(
      material: (m['material'] ?? '').toString(),
      color: (m['color'] ?? '').toString(),
      meters: (m['meters'] is num)
          ? (m['meters'] as num).toDouble()
          : double.tryParse((m['meters'] ?? '0').toString()) ?? 0.0,
      pieceNames:
          (m['pieceNames'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }
}
