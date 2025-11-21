import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa o tipo de usuário no sistema.
enum UserRole {
  gestor,
  participante,
}

// --- NOVO: CLASSE DE CHAVES DE PERMISSÃO ---
/// Define as chaves de permissão granular que um usuário pode ter.
/// Usar constantes evita erros de digitação.
class AppPermissions {
  // Ações do Menu Principal
  static const String canCreateFicha = 'canCreateFicha';
  static const String canViewFichasSalvas = 'canViewFichasSalvas';
  static const String canCreateProduto = 'canCreateProduto';
  static const String canViewProdutos = 'canViewProdutos';
  static const String canCreateMaterial = 'canCreateMaterial';
  static const String canViewMateriais = 'canViewMateriais';
  // ... (Podemos adicionar 'canViewReports', 'canManageBackup' aqui se quisermos)

  // Visualizações do Dashboard
  static const String canViewProducaoDiaria = 'canViewProducaoDiaria';
  static const String canViewFichasEmProducao = 'canViewFichasEmProducao';

  /// Permissões padrão para um novo [UserRole.participante].
  /// Tudo começa como 'false' e o gestor deve liberar.
  static const Map<String, bool> defaultParticipantPermissions = {
    canCreateFicha: false,
    canViewFichasSalvas: false,
    canCreateProduto: false,
    canViewProdutos: false,
    canCreateMaterial: false,
    canViewMateriais: false,
    canViewProducaoDiaria: false,
    canViewFichasEmProducao: false,
  };

  /// Permissões padrão para um [UserRole.gestor].
  /// O Gestor sempre pode tudo.
  static const Map<String, bool> defaultGestorPermissions = {
    canCreateFicha: true,
    canViewFichasSalvas: true,
    canCreateProduto: true,
    canViewProdutos: true,
    canCreateMaterial: true,
    canViewMateriais: true,
    canViewProducaoDiaria: true,
    canViewFichasEmProducao: true,
  };

  /// Retorna um nome amigável para cada chave de permissão (para a UI)
  static String getPermissionLabel(String key) {
    switch (key) {
      case canCreateFicha:
        return 'Pode Criar Novas Fichas';
      case canViewFichasSalvas:
        return 'Pode Ver Fichas Salvas';
      case canCreateProduto:
        return 'Pode Criar Produtos';
      case canViewProdutos:
        return 'Pode Ver Produtos';
      case canCreateMaterial:
        return 'Pode Criar Materiais';
      case canViewMateriais:
        return 'Pode Ver Materiais';
      case canViewProducaoDiaria:
        return 'Pode Ver Card "Produção Diária"';
      case canViewFichasEmProducao:
        return 'Pode Ver Card "Fichas em Produção"';
      default:
        return key;
    }
  }
}
// --- FIM DA NOVA CLASSE ---

/// Modelo de dados para o perfil de um usuário salvo no Firestore.
/// Isso controla as permissões.
class AppUserModel {
  final String uid; // Id do Firebase Auth
  final String email;
  final UserRole role; // 'gestor' ou 'participante'
  final String teamId; // Id da equipe que ele pertence
  final List<String> allowedSectors; // Lista de setores permitidos
  // --- NOVO CAMPO DE PERMISSÕES ---
  final Map<String, bool> permissions;
  // --- FIM DO NOVO CAMPO ---

  AppUserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.teamId,
    this.allowedSectors = const [], // Participantes começam sem setores
    required this.permissions, // Agora é obrigatório
  });

  /// Converte um documento do Firestore (Map) para um objeto AppUserModel.
  factory AppUserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Converte a string 'gestor' ou 'participante' para o enum UserRole
    UserRole role = UserRole.participante;
    if (data['role'] == 'gestor') {
      role = UserRole.gestor;
    }

    // Converte a lista de setores (que pode ser dynamic) para List<String>
    List<String> sectors = [];
    if (data['allowedSectors'] != null) {
      sectors = List<String>.from(data['allowedSectors']);
    }

    // --- LÓGICA DE LEITURA DAS PERMISSÕES ---
    Map<String, bool> perms;
    if (role == UserRole.gestor) {
      // Gestor SEMPRE tem todas as permissões.
      perms = AppPermissions.defaultGestorPermissions;
    } else {
      // Participante: Lê o mapa do Firestore
      final Map<String, bool> savedPerms = data['permissions'] != null
          ? Map<String, bool>.from(data['permissions'])
          : {};

      // Mescla os padrões (para o caso de termos adicionado uma nova permissão)
      // com as permissões salvas.
      perms = {...AppPermissions.defaultParticipantPermissions, ...savedPerms};
    }
    // --- FIM DA LÓGICA DE LEITURA ---

    return AppUserModel(
      uid: doc.id, // O ID do documento é o UID do usuário
      email: data['email'] ?? '',
      role: role,
      teamId: data['teamId'] ?? '',
      allowedSectors: sectors,
      permissions: perms, // Passa o mapa de permissões
    );
  }

  /// Converte o objeto AppUserModel para um Map (para salvar no Firestore).
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role.name, // Salva o enum como string (ex: 'gestor')
      'teamId': teamId,
      'allowedSectors': allowedSectors,
      'permissions': permissions, // Salva o novo mapa de permissões
    };
  }
}
