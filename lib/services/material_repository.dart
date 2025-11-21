// lib/services/material_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// O import do 'material_item.dart' (Hive) foi removido
import 'package:gestor_calcados_new/models/material_model.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class MaterialRepository {
  static final MaterialRepository _instance = MaterialRepository._internal();
  factory MaterialRepository() {
    return _instance;
  }
  MaterialRepository._internal();

  // Remove as variáveis do Hive (_box, _isInitialized)
  // Adiciona a instância do Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collectionName = 'materials'; // O nome da sua coleção

  // O 'init()' não é mais necessário. O Firebase é inicializado no main.dart.

  /// Salva (cria ou atualiza) um material no Firestore.
  /// AGORA RECEBE O NOVO 'MaterialModel'
  Future<void> saveMaterial(MaterialModel material) async {
    try {
      await _db
          .collection(_collectionName)
          .doc(material.id)
          .set(material.toFirestore());
    } catch (e) {
      debugPrint('Erro em MaterialRepository.saveMaterial: $e');
      rethrow; // Re-lança o erro para a UI (formulário) lidar
    }
  }

  /// [MUDANÇA] Busca um material específico pelo seu ID de documento.
  /// AGORA É ASSÍNCRONO e retorna um 'Future'
  Future<MaterialModel?> getById(String id) async {
    try {
      final doc = await _db.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return MaterialModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Erro em MaterialRepository.getById: $e');
      return null;
    }
  }

  /// [MUDANÇA CRÍTICA] Busca todos os materiais PARA UM TIME (teamId).
  /// Esta função agora é ASSÍNCRONA e REQUER o teamId.
  Future<List<MaterialModel>> getAll(String teamId) async {
    if (teamId.isEmpty) {
      debugPrint(
          'Aviso: MaterialRepository.getAll() chamado com teamId vazio.');
      return [];
    }

    try {
      // Esta consulta requer um índice:
      // Coleção: 'materials', Campo 1: 'teamId' (Crescente), Campo 2: 'name' (Crescente)
      final query = await _db
          .collection(_collectionName)
          .where('teamId', isEqualTo: teamId)
          .orderBy('name') // Mantém a ordenação alfabética
          .get();

      final materials =
          query.docs.map((doc) => MaterialModel.fromFirestore(doc)).toList();
      return materials;
    } catch (e) {
      debugPrint('Erro em MaterialRepository.getAll: $e');
      // Se falhar (ex: índice faltando), retorna lista vazia
      return [];
    }
  }

  /// [MUDANÇA] Deleta um material pelo seu ID.
  /// (A lógica interna mudou, mas a chamada é a mesma)
  Future<void> deleteById(String id) async {
    try {
      await _db.collection(_collectionName).doc(id).delete();
    } catch (e) {
      debugPrint('Erro em MaterialRepository.deleteById: $e');
    }
  }

  // A função getBox() foi removida pois era específica do Hive.
}
