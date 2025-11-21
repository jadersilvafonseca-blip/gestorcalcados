import 'package:cloud_firestore/cloud_firestore.dart';

// -------------------------------------------------------------------
// --- CLASSE "PIECE" (PEÇA) ---
// Define uma peça individual que compõe um produto.
// Esta classe será aninhada dentro do ProductModel.
// -------------------------------------------------------------------
class Piece {
  final String name;
  final String material;
  final String color;
  final double areaPerPair; // (Ex: 0.0198)

  Piece({
    required this.name,
    required this.material,
    required this.color,
    required this.areaPerPair,
  });

  /// Converte este objeto Piece para um Map (para salvar no Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'material': material,
      'color': color,
      'areaPerPair': areaPerPair,
    };
  }

  /// Cria um objeto Piece a partir de um Map (lido do Firestore)
  factory Piece.fromMap(Map<String, dynamic> map) {
    return Piece(
      name: map['name'] ?? '',
      material: map['material'] ?? '',
      color: map['color'] ?? '',
      areaPerPair: (map['areaPerPair'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// -------------------------------------------------------------------
// --- CLASSE "PRODUCT MODEL" (PRODUTO) ---
// Este é o modelo principal que será salvo na coleção 'products'
// -------------------------------------------------------------------
class ProductModel {
  final String id; // ID do documento no Firestore
  final String teamId; // ID da equipe/gestor que cadastrou
  final String reference; // Código ou referência (ex: "1020-B")
  final String name; // Nome do modelo (ex: "Bota Cano Curto")
  final String brand; // Marca (ex: "Marca X")
  final String color; // Cor (ex: "Preto")
  final List<Piece> pieces; // A lista de peças que compõem o produto
  final Timestamp createdAt; // Data de cadastro

  ProductModel({
    required this.id,
    required this.teamId,
    required this.reference,
    required this.name,
    required this.brand,
    required this.color,
    required this.pieces,
    required this.createdAt,
  });

  /// Converte um documento do Firestore (Map) para um objeto ProductModel.
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Converte a lista de Maps (do Firestore) para uma List<Piece>
    final List<Piece> piecesList = [];
    if (data['pieces'] != null) {
      for (var pieceMap in (data['pieces'] as List)) {
        piecesList.add(Piece.fromMap(pieceMap as Map<String, dynamic>));
      }
    }

    return ProductModel(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      reference: data['reference'] ?? '',
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      color: data['color'] ?? '',
      pieces: piecesList,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  /// Converte o objeto ProductModel para um Map (para salvar no Firestore).
  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'reference': reference,
      'name': name,
      'brand': brand,
      'color': color,
      // Converte a List<Piece> para uma List<Map>
      'pieces': pieces.map((piece) => piece.toMap()).toList(),
      'createdAt': createdAt,
    };
  }
}
