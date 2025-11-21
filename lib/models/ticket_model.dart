import 'package:cloud_firestore/cloud_firestore.dart';

/// MaterialEstimate: representa consumo de material para a ficha
class MaterialEstimate {
  final String material;
  final String color;
  final double meters;
  final List<String> pieceNames;

  MaterialEstimate({
    required this.material,
    required this.color,
    required this.meters,
    required this.pieceNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'material': material,
      'color': color,
      'meters': meters,
      'pieceNames': pieceNames,
    };
  }

  factory MaterialEstimate.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return MaterialEstimate(
          material: '', color: '', meters: 0.0, pieceNames: []);
    }
    return MaterialEstimate(
      material: map['material'] as String? ?? '',
      color: map['color'] as String? ?? '',
      meters: (map['meters'] as num?)?.toDouble() ?? 0.0,
      pieceNames: map['pieceNames'] != null
          ? List<String>.from(map['pieceNames'] as List)
          : <String>[],
    );
  }
}

// -------------------------------------------------------------------
// Movimentação e status
// -------------------------------------------------------------------
enum TicketStatus { created, inProgress, completed, paused }

class MovementHistory {
  final String sectorId;
  final String sectorName;
  final Timestamp inAt;
  final Timestamp? outAt;
  final String responsibleUserId;

  MovementHistory({
    required this.sectorId,
    required this.sectorName,
    required this.inAt,
    this.outAt,
    required this.responsibleUserId,
  });

  factory MovementHistory.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return MovementHistory(
        sectorId: '',
        sectorName: '',
        inAt: Timestamp.now(),
        outAt: null,
        responsibleUserId: '',
      );
    }
    final inAt =
        map['inAt'] is Timestamp ? map['inAt'] as Timestamp : Timestamp.now();
    final outAt = map['outAt'] is Timestamp ? map['outAt'] as Timestamp : null;
    return MovementHistory(
      sectorId: map['sectorId'] as String? ?? '',
      sectorName: map['sectorName'] as String? ?? '',
      inAt: inAt,
      outAt: outAt,
      responsibleUserId: map['responsibleUserId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sectorId': sectorId,
      'sectorName': sectorName,
      'inAt': inAt,
      'outAt': outAt,
      'responsibleUserId': responsibleUserId,
    };
  }
}

// -------------------------------------------------------------------
// TicketModel
// -------------------------------------------------------------------
class TicketModel {
  final String id;
  final String teamId;
  final String productId;
  final String productName;
  final String productReference;
  final String productColor;
  final int pairs;

  /// Pode ser null logo após a criação se você usar FieldValue.serverTimestamp()
  final Timestamp? createdAt;
  final String createdByUid;
  final TicketStatus status;

  final String currentSectorId;
  final String currentSectorName;
  final Timestamp? lastMovedAt;

  final List<MovementHistory> history;

  final String cliente;
  final String pedido;
  final String observacao;
  final Map<String, int> grade;

  final List<MaterialEstimate> materialsUsed;

  TicketModel({
    required this.id,
    required this.teamId,
    required this.productId,
    required this.productName,
    required this.productReference,
    required this.productColor,
    required this.pairs,
    required this.createdAt,
    required this.createdByUid,
    required this.status,
    required this.currentSectorId,
    required this.currentSectorName,
    this.lastMovedAt,
    required this.history,
    required this.cliente,
    required this.pedido,
    required this.observacao,
    required this.grade,
    required this.materialsUsed,
  });

  /// Helper: retorna createdAt ou Timestamp.now() (não altera o campo)
  Timestamp get createdAtOrNow => createdAt ?? Timestamp.now();

  /// Constrói a partir de DocumentSnapshot com casts seguros
  factory TicketModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    // history
    final historyList = <MovementHistory>[];
    if (data['history'] is List) {
      for (final h in data['history'] as List) {
        if (h is Map<String, dynamic>) {
          historyList.add(MovementHistory.fromMap(h));
        } else if (h is Map) {
          historyList
              .add(MovementHistory.fromMap(Map<String, dynamic>.from(h)));
        }
      }
    }

    // materialsUsed
    final materialsList = <MaterialEstimate>[];
    if (data['materialsUsed'] is List) {
      for (final m in data['materialsUsed'] as List) {
        if (m is Map<String, dynamic>) {
          materialsList.add(MaterialEstimate.fromMap(m));
        } else if (m is Map) {
          materialsList
              .add(MaterialEstimate.fromMap(Map<String, dynamic>.from(m)));
        }
      }
    }

    // status safe parse
    TicketStatus status = TicketStatus.created;
    final rawStatus = data['status'] as String?;
    if (rawStatus != null) {
      try {
        status = TicketStatus.values.firstWhere((e) => e.name == rawStatus);
      } catch (_) {
        status = TicketStatus.created;
      }
    }

    // grade map safe
    final Map<String, int> gradeMap = {};
    if (data['grade'] is Map) {
      (data['grade'] as Map).forEach((k, v) {
        gradeMap[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    // timestamps safe
    final createdAt =
        data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
    final lastMovedAt = data['lastMovedAt'] is Timestamp
        ? data['lastMovedAt'] as Timestamp
        : null;

    // =====================================================================
    // IMPORTANTE: LEITURA DO 'id'
    // =====================================================================
    // O 'id' do modelo vem do ID do documento (doc.id) OU
    // de um campo 'id' salvo dentro do documento, se 'doc.id' não for o que queremos.
    // A sua lógica de _generateNextTicketId PROCURA um campo 'id'.
    // A sua lógica de fromFirestore usa 'doc.id'.
    // Vamos manter 'doc.id' por enquanto, pois é o padrão.
    // A correção CRÍTICA está no toFirestore().
    // =====================================================================
    String docId = doc.id;
    String fieldId = data['id'] as String? ?? '';

    return TicketModel(
      id: docId.isNotEmpty ? docId : fieldId, // Usa o doc.id como principal
      teamId: data['teamId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      productReference: data['productReference'] as String? ?? '',
      productColor: data['productColor'] as String? ?? '',
      pairs: (data['pairs'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      createdByUid: data['createdByUid'] as String? ?? '',
      status: status,
      currentSectorId: data['currentSectorId'] as String? ?? 'created',
      currentSectorName: data['currentSectorName'] as String? ?? 'Criada',
      lastMovedAt: lastMovedAt,
      history: historyList,
      cliente: data['cliente'] as String? ?? '',
      pedido: data['pedido'] as String? ?? '',
      observacao: data['observacao'] as String? ?? '',
      grade: gradeMap,
      materialsUsed: materialsList,
    );
  }

  /// Para salvar no Firestore:
  Map<String, dynamic> toFirestore() {
    return {
      // ============================================================
      // --- CORREÇÃO AQUI ---
      // ============================================================
      'id':
          id, // <-- 1. ADICIONADO para a consulta _generateNextTicketId funcionar
      'createdAt': createdAt, // <-- 2. DESCOMENTADO para a ordenação funcionar
      // ============================================================

      'teamId': teamId,
      'productId': productId,
      'productName': productName,
      'productReference': productReference,
      'productColor': productColor,
      'pairs': pairs,
      'createdByUid': createdByUid,
      'status': status.name,
      'currentSectorId': currentSectorId,
      'currentSectorName': currentSectorName,
      'lastMovedAt': lastMovedAt,
      'history': history.map((h) => h.toMap()).toList(),
      'cliente': cliente,
      'pedido': pedido,
      'observacao': observacao,
      'grade': grade,
      'materialsUsed': materialsUsed.map((m) => m.toMap()).toList(),
    };
  }
}
