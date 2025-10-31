import 'package:hive/hive.dart';

// 1. Importa os MODELOS que definem as classes e enums
// O enum Setor e a classe Ficha estão em sector.dart
import 'package:gestor_calcados_new/models/sector.dart';
import 'package:gestor_calcados_new/models/app_user.dart';

// 2. REMOVIDO: Não importe os arquivos '.g.dart' diretamente
// import 'package:gestor_calcados_new/models/sector.g.dart';
// import 'package:gestor_calcados_new/models/app_user.g.dart';

/// Registra todos os TypeAdapters gerados pelo build_runner.
/// Esta função DEVE ser chamada no main.dart APÓS Hive.initFlutter().
Future<void> registerHiveAdapters() async {
  // Registra Adapters (com verificação para evitar erro no Hot Restart)
  // Os nomes das classes Adapter (SetorAdapter, etc.) estão disponíveis
  // porque os arquivos '.g.dart' são "part of" os arquivos de modelo importados acima.

  // Adapters definidos em sector.dart / sector.g.dart
  if (!Hive.isAdapterRegistered(10)) {
    // typeId: Setor
    Hive.registerAdapter(SetorAdapter());
    print('[Hive Adapters] SetorAdapter registered.');
  }
  // REMOVIDO: Registro do TipoGargaloAdapter (TypeID 11 foi removido do modelo)
  // if (!Hive.isAdapterRegistered(11)) { ... }

  if (!Hive.isAdapterRegistered(12)) {
    // typeId: Ficha
    Hive.registerAdapter(FichaAdapter());
    print('[Hive Adapters] FichaAdapter registered.');
  }
  // REMOVIDO: Registro do GargaloAdapter (TypeID 13 foi removido do modelo)
  // if (!Hive.isAdapterRegistered(13)) { ... }

  // Adapters definidos em app_user.dart / app_user.g.dart
  if (!Hive.isAdapterRegistered(30)) {
    // typeId: UserRole
    Hive.registerAdapter(UserRoleAdapter());
    print('[Hive Adapters] UserRoleAdapter registered.');
  }
  if (!Hive.isAdapterRegistered(31)) {
    // typeId: AppUser
    Hive.registerAdapter(AppUserAdapter());
    print('[Hive Adapters] AppUserAdapter registered.');
  }

  // Adicione aqui o registro para outros adapters que você criar
}
