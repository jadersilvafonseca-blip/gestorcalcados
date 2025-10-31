import 'package:hive/hive.dart';
// Importa o enum Setor do arquivo correto
import 'package:gestor_calcados_new/models/sector.dart';

// OBRIGATÓRIO: Esta linha DEVE ser a primeira após os imports
part 'app_user.g.dart';

/// Define as funções do usuário no sistema
@HiveType(typeId: 30) // << ID ÚNICO
enum UserRole {
  @HiveField(0)
  admin('Administrador'), // Pode ver/editar tudo
  @HiveField(1)
  manager('Gerente de Setor'); // Pode ver/editar apenas seu setor

  final String label;
  const UserRole(this.label);
}

/// Modelo para o usuário do aplicativo
@HiveType(typeId: 31) // << ID ÚNICO
class AppUser extends HiveObject {
  // << DEVE extender HiveObject
  @HiveField(0)
  final String id; // Pode ser o e-mail ou um ID único

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String hashedPassword; // Senha DEVE ser armazenada como hash

  @HiveField(4)
  final UserRole role;

  // Setor responsável (APENAS para Managers)
  // Se for Admin, este campo pode ser nulo ou um valor padrão
  @HiveField(5)
  final Setor? responsibleSector; // << Setor deve ser um HiveType

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.hashedPassword,
    required this.role,
    this.responsibleSector,
  });

  // Métodos de conveniência (não essenciais para Hive, mas úteis)
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
}
