import 'package:hive/hive.dart'; // MUDANÇA: Era 'package.hive', agora é 'package:hive'

part 'user_model.g.dart'; // Você precisará rodar o build_runner para gerar isso

@HiveType(typeId: 0) // ID único para o modelo
class UserModel extends HiveObject {
  @HiveField(0)
  String nome;

  @HiveField(1)
  String telefone;

  @HiveField(2)
  String email;

  @HiveField(3)
  String login; // Usaremos como chave principal

  @HiveField(4)
  String senha; // Senha de 4 dígitos

  @HiveField(5)
  String funcao; // "Líder de Setor" ou "Gestor / Administrador"

  UserModel({
    required this.nome,
    required this.telefone,
    required this.email,
    required this.login,
    required this.senha,
    required this.funcao,
  });
}
