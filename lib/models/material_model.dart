import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de dados para um Material salvo no Firestore.
class MaterialModel {
  final String id; // ID do documento no Firestore
  final String teamId; // ID da equipe/gestor que cadastrou
  final String name;
  final String supplier; // Fornecedor
  final double price; // Preço (R$)
  final double height; // Altura (m) (Ex: 1.4)
  final List<String> colors; // Lista de cores
  final Timestamp createdAt;

  MaterialModel({
    required this.id,
    required this.teamId,
    required this.name,
    required this.supplier,
    required this.price,
    required this.height,
    required this.colors,
    required this.createdAt,
  });

  /// Converte um documento do Firestore (Map) para um objeto MaterialModel.
  factory MaterialModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return MaterialModel(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      name: data['name'] ?? '',
      supplier: data['supplier'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      height: (data['height'] as num?)?.toDouble() ?? 1.4, // Padrão 1.4
      colors: data['colors'] != null ? List<String>.from(data['colors']) : [],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  /// Converte o objeto MaterialModel para um Map (para salvar no Firestore).
  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'name': name,
      'supplier': supplier,
      'price': price,
      'height': height,
      'colors': colors,
      'createdAt': createdAt,
    };
  }
}
