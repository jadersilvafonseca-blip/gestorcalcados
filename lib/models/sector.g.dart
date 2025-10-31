// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sector.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FichaAdapter extends TypeAdapter<Ficha> {
  @override
  final int typeId = 12;

  @override
  Ficha read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ficha(
      codigo: fields[0] as String,
      cliente: fields[1] as String,
      produto: fields[2] as String,
      cor: fields[3] as String,
      marca: fields[4] as String,
      pares: fields[5] as int,
      setor: fields[6] as Setor,
      data: fields[7] as DateTime,
      finalizada: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Ficha obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.codigo)
      ..writeByte(1)
      ..write(obj.cliente)
      ..writeByte(2)
      ..write(obj.produto)
      ..writeByte(3)
      ..write(obj.cor)
      ..writeByte(4)
      ..write(obj.marca)
      ..writeByte(5)
      ..write(obj.pares)
      ..writeByte(6)
      ..write(obj.setor)
      ..writeByte(7)
      ..write(obj.data)
      ..writeByte(8)
      ..write(obj.finalizada);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FichaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SetorAdapter extends TypeAdapter<Setor> {
  @override
  final int typeId = 10;

  @override
  Setor read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Setor.almoxarifado;
      case 1:
        return Setor.corte;
      case 2:
        return Setor.pesponto;
      case 3:
        return Setor.banca1;
      case 4:
        return Setor.banca2;
      case 5:
        return Setor.montagem;
      case 6:
        return Setor.expedicao;
      default:
        return Setor.almoxarifado;
    }
  }

  @override
  void write(BinaryWriter writer, Setor obj) {
    switch (obj) {
      case Setor.almoxarifado:
        writer.writeByte(0);
        break;
      case Setor.corte:
        writer.writeByte(1);
        break;
      case Setor.pesponto:
        writer.writeByte(2);
        break;
      case Setor.banca1:
        writer.writeByte(3);
        break;
      case Setor.banca2:
        writer.writeByte(4);
        break;
      case Setor.montagem:
        writer.writeByte(5);
        break;
      case Setor.expedicao:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
