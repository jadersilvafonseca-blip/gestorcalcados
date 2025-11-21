// lib/models/dynamic_sector.dart

class DynamicSector {
  final String nome;
  final int emProducao;
  final int producaoDia;
  final DateTime atualizacao;

  DynamicSector({
    required this.nome,
    required this.emProducao,
    required this.producaoDia,
    required this.atualizacao,
  });

  DynamicSector copyWith({
    String? nome,
    int? emProducao,
    int? producaoDia,
    DateTime? atualizacao,
  }) {
    return DynamicSector(
      nome: nome ?? this.nome,
      emProducao: emProducao ?? this.emProducao,
      producaoDia: producaoDia ?? this.producaoDia,
      atualizacao: atualizacao ?? this.atualizacao,
    );
  }
}
