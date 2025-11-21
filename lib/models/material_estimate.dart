// TODO Implement this library.
// lib/models/material_estimate.dart

class MaterialEstimate {
  final String material; // nome do material (ex: "Couro")
  final String color; // cor (ex: "Preto")
  final List<String>
      pieceNames; // peças que consomem esse material (ex: ["Cabedal", "Palmilha"])
  final double meters; // metros consumidos (ex: 0.75)

  MaterialEstimate({
    required this.material,
    required this.color,
    required this.pieceNames,
    required this.meters,
  });

  // Factory defensiva a partir de dynamic / Map (Firestore / Hive)
  factory MaterialEstimate.fromMap(dynamic raw) {
    if (raw == null) {
      return MaterialEstimate(
        material: '',
        color: '',
        pieceNames: const <String>[],
        meters: 0.0,
      );
    }

    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final material =
        map['material']?.toString() ?? map['name']?.toString() ?? '';
    final color = map['color']?.toString() ?? map['cor']?.toString() ?? '';
    final pieceObj = map['pieceNames'] ?? map['pieces'] ?? map['piece'] ?? [];
    final List<String> pieceNames = <String>[];
    if (pieceObj is List) {
      for (final p in pieceObj) {
        if (p != null) pieceNames.add(p.toString());
      }
    } else if (pieceObj != null) {
      pieceNames.add(pieceObj.toString());
    }

    double meters = 0.0;
    final rawMeters = map['meters'] ?? map['metros'] ?? map['amount'] ?? 0.0;
    if (rawMeters is num) {
      meters = rawMeters.toDouble();
    } else {
      meters = double.tryParse(rawMeters.toString()) ?? 0.0;
    }

    return MaterialEstimate(
      material: material,
      color: color,
      pieceNames: pieceNames,
      meters: meters,
    );
  }

  Map<String, dynamic> toMap() => {
        'material': material,
        'color': color,
        'pieceNames': pieceNames,
        'meters': meters,
      };
}
