import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'sector.g.dart'; // Mantém para Setor e Ficha

/// -----------------------------------------------------------------
/// 1. Enum: Setor (Configurado para Hive)
/// -----------------------------------------------------------------
@HiveType(typeId: 10) // ID ÚNICO para o Hive
enum Setor {
  @HiveField(0)
  almoxarifado('Almoxarifado'),
  @HiveField(1)
  corte('Corte'),
  @HiveField(2)
  pesponto('Pesponto'),
  @HiveField(3)
  banca1('Banca 1'),
  @HiveField(4)
  banca2('Banca 2'),
  @HiveField(5)
  montagem('Montagem'),
  @HiveField(6)
  expedicao('Expedição');

  final String label;
  const Setor(this.label);

  // Getter para o ícone (mantido)
  IconData get icon {
    switch (this) {
      case Setor.almoxarifado:
        return Icons.inventory_2_outlined;
      case Setor.corte:
        return Icons.content_cut;
      case Setor.pesponto:
        return Icons.precision_manufacturing_outlined;
      case Setor.banca1:
        return Icons.precision_manufacturing_outlined;
      case Setor.banca2:
        return Icons.precision_manufacturing_outlined;
      case Setor.montagem:
        return Icons.construction_outlined;
      case Setor.expedicao:
        return Icons.local_shipping_outlined;
    }
  }

  String get id => name;
}

/// -----------------------------------------------------------------
/// REMOVIDO: Enum TipoGargalo
/// -----------------------------------------------------------------
// enum TipoGargalo { ... } // Código removido

/// -----------------------------------------------------------------
/// 3. Modelo: Ficha (Configurado para Hive)
/// -----------------------------------------------------------------
@HiveType(typeId: 12) // ID ÚNICO para o Hive
class Ficha {
  @HiveField(0)
  final String codigo;
  @HiveField(1)
  final String cliente;
  @HiveField(2)
  final String produto;
  @HiveField(3)
  final String cor;
  @HiveField(4)
  final String marca;
  @HiveField(5)
  final int pares;
  @HiveField(6)
  final Setor setor; // Setor agora é um HiveType
  @HiveField(7)
  final DateTime data;
  @HiveField(8)
  final bool finalizada;

  const Ficha({
    required this.codigo,
    required this.cliente,
    required this.produto,
    required this.cor,
    required this.marca,
    required this.pares,
    required this.setor,
    required this.data,
    this.finalizada = false,
  });

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'cliente': cliente,
        'produto': produto,
        'cor': cor,
        'marca': marca,
        'pares': pares,
        'setor': setor.name,
        'data': data.toIso8601String(),
        'finalizada': finalizada,
      };

  factory Ficha.fromMap(Map<String, dynamic> map) {
    return Ficha(
      codigo: map['codigo'] ?? '',
      cliente: map['cliente'] ?? '',
      produto: map['produto'] ?? '',
      cor: map['cor'] ?? '',
      marca: map['marca'] ?? '',
      pares: map['pares'] ?? 0,
      setor: Setor.values.firstWhere(
        (s) => s.name == map['setor'],
        orElse: () => Setor.almoxarifado,
      ),
      data: DateTime.tryParse(map['data'] ?? '') ?? DateTime.now(),
      finalizada: map['finalizada'] ?? false,
    );
  }
}
