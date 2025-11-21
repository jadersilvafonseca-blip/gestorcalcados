import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/sector_models.dart'
    hide kTransitSectorId;
import 'package:gestor_calcados_new/services/production_manager.dart';
import 'package:gestor_calcados_new/pages/login_page.dart'; // Importe a LoginPage
import 'package:gestor_calcados_new/pages/team_management_page.dart';
import 'create_ticket_page.dart';
import 'tickets_page.dart';
import 'scanner_page.dart';
import 'product_form_page.dart';
import 'product_list_page.dart';
import 'report_page.dart';
import 'sector_settings_page.dart';
import 'material_form_page.dart';
import 'material_list_page.dart';

// Helper para pegar nome do setor (usa o PM)
String _getSectorName(String sectorId) {
  if (sectorId == kTransitSectorId) return 'Trânsito';

  // Usa o ProductionManager que já tem os setores carregados
  try {
    final sectorModel = ProductionManager.instance.getSectorModelById(sectorId);
    return sectorModel?.label ?? sectorId;
  } catch (_) {
    return sectorId;
  }
}

// ====================================================================
// WIDGET PAI (STATELESS)
// ====================================================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return LoginPage();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots(),
      builder: (context, firestoreSnapshot) {
        if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!firestoreSnapshot.hasData || !firestoreSnapshot.data!.exists) {
          FirebaseAuth.instance.signOut();
          return LoginPage();
        }

        if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
          final appUser = AppUserModel.fromFirestore(firestoreSnapshot.data!);
          return _DashboardContent(user: appUser);
        }

        return LoginPage();
      },
    );
  }
}

// ====================================================================
// CONTEÚDO DO DASHBOARD (STATEFUL)
// ====================================================================

class _DashboardContent extends StatefulWidget {
  final AppUserModel user;
  const _DashboardContent({super.key, required this.user});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  bool _ready = false;
  final ProductionManager _pm = ProductionManager.instance;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(_DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.teamId != widget.user.teamId) {
      setState(() => _ready = false);
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await _pm.initFirebase();

      // --- DEBUG ---
      debugPrint(
          "### TENTANDO CARREGAR SETORES PARA O TEAM ID: [${widget.user.teamId}]");

      await _pm.getAllSectorModels(widget.user.teamId);

      debugPrint("### SETORES CARREGADOS COM SUCESSO.");
    } catch (e) {
      debugPrint('### ERRO CRÍTICO AO CARREGAR SETORES: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao carregar dados dos setores: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGestor = widget.user.role == UserRole.gestor;
    final perms = widget.user.permissions;

    final bool canSeeProdutos =
        (perms[AppPermissions.canCreateProduto] ?? false) ||
            (perms[AppPermissions.canViewProdutos] ?? false);

    final bool canSeeMateriais =
        (perms[AppPermissions.canCreateMaterial] ?? false) ||
            (perms[AppPermissions.canViewMateriais] ?? false);

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0, 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu Principal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.user.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Função: ${widget.user.role.name == 'gestor' ? 'Gestor' : 'Participante'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
            ),
            if (isGestor)
              ListTile(
                leading: Icon(Icons.group_work_outlined,
                    color: Theme.of(context).primaryColor),
                title: Text(
                  'Gerenciar Equipe',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeamManagementPage(gestor: widget.user),
                    ),
                  );
                },
              ),
            if (perms[AppPermissions.canCreateFicha] ?? false)
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Criar Nova Ficha'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CreateTicketPage(user: widget.user),
                    fullscreenDialog: true,
                  ));
                },
              ),
            if (perms[AppPermissions.canViewFichasSalvas] ?? false)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Ver Fichas Salvas'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TicketsPage(user: widget.user),
                    fullscreenDialog: true,
                  ));
                },
              ),
            if (isGestor) ...[
              ListTile(
                leading: const Icon(Icons.assessment_outlined),
                title: const Text('Relatório de Produção'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReportPage(user: widget.user),
                  ));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configurar Setores'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SectorSettingsPage(user: widget.user),
                  ));
                  await _pm.getAllSectorModels(widget.user.teamId);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ],
            if (canSeeProdutos) const Divider(),
            if (perms[AppPermissions.canCreateProduto] ?? false)
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Cadastrar Novo Produto'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductFormPage(user: widget.user),
                    fullscreenDialog: true,
                  ));
                },
              ),
            if (perms[AppPermissions.canViewProdutos] ?? false)
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Ver Produtos Cadastrados'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductListPage(user: widget.user),
                  ));
                },
              ),
            if (canSeeMateriais) const Divider(),
            if (perms[AppPermissions.canCreateMaterial] ?? false)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Cadastrar Novo Material'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MaterialFormPage(user: widget.user),
                    fullscreenDialog: true,
                  ));
                },
              ),
            if (perms[AppPermissions.canViewMateriais] ?? false)
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Ver Materiais Cadastrados'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MaterialListPage(user: widget.user),
                  ));
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text(
                'Sair',
                style: TextStyle(color: Colors.red.shade700),
              ),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColorDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Painel de Produção 👟',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [],
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : _DashboardBody(
                user: widget.user,
              ),
      ),
      floatingActionButton: null,
    );
  }
}

// ====================================================================
// _DashboardBody (Corpo do Dashboard)
// ====================================================================

class _DashboardBody extends StatefulWidget {
  final AppUserModel user;
  const _DashboardBody({required this.user});

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final ProductionManager _pm = ProductionManager.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference get _configDocRef => _db
      .collection('teams')
      .doc(widget.user.teamId)
      .collection('config')
      .doc('dashboard_settings');

  static const String _kMainSectorKey = 'main_sector_id';
  String _mainSectorId = '';

  late Stream<List<Map<String, dynamic>>> _bottlenecksStream;
  late Stream<List<Map<String, dynamic>>> _wipStream;
  late Stream<List<ConfigurableSector>> _sectorsStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
    _loadMainSectorConfig();
  }

  void _initializeStreams() {
    _bottlenecksStream = _pm.getAllActiveBottlenecksStream(widget.user.teamId);
    _wipStream = _pm.getAllWorkInProgressFichasStream(widget.user.teamId);
    _sectorsStream =
        _pm.getAllSectorModelsStream(widget.user.teamId).asBroadcastStream();
  }

  @override
  void didUpdateWidget(covariant _DashboardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.teamId != widget.user.teamId) {
      _initializeStreams();
      _loadMainSectorConfig();
    }
  }

  Future<void> _loadMainSectorConfig() async {
    try {
      final settingsDoc = await _configDocRef.get();
      _mainSectorId = (settingsDoc.data() as Map? ?? {})[_kMainSectorKey] ?? '';

      if (_mainSectorId.isEmpty) {
        final sectors = await _pm.getAllSectorModels(widget.user.teamId);
        if (sectors.isNotEmpty) {
          _mainSectorId = sectors.first.firestoreId;
          await _configDocRef.set(
            {_kMainSectorKey: _mainSectorId},
            SetOptions(merge: true),
          );
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Erro ao carregar setor principal: $e");
    }
  }

  void _showMainSectorConfigDialog(
      BuildContext context, List<ConfigurableSector> sectorModels) {
    String? selectedSectorId = _mainSectorId;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Setor Principal no Dashboard'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Escolha qual setor de produção será exibido no topo:'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.maxFinite,
                    child: DropdownButtonFormField<String>(
                      value:
                          selectedSectorId!.isEmpty ? null : selectedSectorId,
                      decoration: const InputDecoration(
                        labelText: 'Setor Principal',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          sectorModels.map<DropdownMenuItem<String>>((sector) {
                        return DropdownMenuItem<String>(
                          value: sector.firestoreId,
                          child: Text(sector.label),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          selectedSectorId = newValue;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FilledButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    if (selectedSectorId != null) {
                      await _configDocRef.set(
                        {_kMainSectorKey: selectedSectorId},
                        SetOptions(merge: true),
                      );
                      setState(() {
                        _mainSectorId = selectedSectorId!;
                      });
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showActiveBottlenecksDialog(
      BuildContext context, List<Map<String, dynamic>> bottlenecks) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gargalos Ativos'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bottlenecks.length,
              itemBuilder: (context, index) {
                final bottleneck = bottlenecks[index];
                final sectorId = bottleneck['sectorId'];
                final sectorName = _getSectorName(sectorId);
                String reason = bottleneck['reason'] ?? 'Desconhecido';
                if (reason == kOtherReason) {
                  reason = bottleneck['customReason'] ?? 'Outros';
                } else if (reason == kMissingPartReason) {
                  reason =
                      'Reposição de peça: ${bottleneck['partName'] ?? 'Não especificada'}';
                }

                return ListTile(
                  title: Text(sectorName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(reason),
                  trailing: TextButton(
                    child: const Text('Resolver'),
                    onPressed: () async {
                      await _pm.resolveBottleneck(
                          bottleneckKey: bottleneck['id']);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Fechar'),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = widget.user.permissions;

    return CustomScrollView(
      slivers: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _bottlenecksStream,
          builder: (context, snapshot) {
            final bottlenecks = snapshot.data ?? [];
            if (bottlenecks.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: InkWell(
                onTap: () => _showActiveBottlenecksDialog(context, bottlenecks),
                child: _GlobalBottleneckBanner(bottlenecks: bottlenecks),
              ),
            );
          },
        ),
        if (perms[AppPermissions.canViewProducaoDiaria] ?? false)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: StreamBuilder<List<ConfigurableSector>>(
                stream: _sectorsStream,
                builder: (context, sectorListSnapshot) {
                  final allSectors = sectorListSnapshot.data ?? [];
                  ConfigurableSector? mainSector;
                  if (_mainSectorId.isNotEmpty && allSectors.isNotEmpty) {
                    try {
                      mainSector = allSectors
                          .firstWhere((s) => s.firestoreId == _mainSectorId);
                    } catch (_) {
                      mainSector = null;
                    }
                  }

                  return StreamBuilder<int>(
                    stream: _pm.getProducaoDoDiaStream(
                        _mainSectorId, widget.user.teamId),
                    builder: (context, prodSnapshot) {
                      final totalHoje = prodSnapshot.data ?? 0;
                      return _ResumoGeral(
                        totalHoje: totalHoje,
                        mainSector: mainSector,
                        onEdit: widget.user.role == UserRole.gestor
                            ? () =>
                                _showMainSectorConfigDialog(context, allSectors)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        if (perms[AppPermissions.canViewFichasEmProducao] ?? false)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _wipStream,
                builder: (context, snapshot) {
                  final wipFichas = snapshot.data ?? [];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 2,
                    child: InkWell(
                      onTap: () {
                        _showWorkInProgressBottomSheet(context, wipFichas);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.sync,
                                color: Theme.of(context).primaryColor,
                                size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fichas em Produção (${wipFichas.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Toque para ver e pesquisar as fichas',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Theme.of(context).primaryColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Text(
              'Visão por Setor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        StreamBuilder<List<ConfigurableSector>>(
          stream: _sectorsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )));
            }
            if (snapshot.hasError) {
              return SliverToBoxAdapter(
                  child: Center(
                      child:
                          Text('Erro ao carregar setores: ${snapshot.error}')));
            }

            final allSectorModels = snapshot.data ?? [];

            final List<ConfigurableSector> sectorList;
            if (widget.user.role == UserRole.gestor) {
              sectorList = allSectorModels;
            } else {
              sectorList = allSectorModels.where((sector) {
                return widget.user.allowedSectors.contains(sector.firestoreId);
              }).toList();
            }

            if (sectorList.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        const Text('Sem setores atribuídos',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'Você ainda não tem permissão para ver setores. Peça ao gestor da sua equipe para liberar seu acesso.',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.87,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final s = sectorList[index];

                    return StreamBuilder<int>(
                      stream: _pm.getProducaoDoDiaStream(
                          s.firestoreId, widget.user.teamId),
                      builder: (context, prodSnapshot) {
                        return StreamBuilder<int>(
                          stream: _pm.getFichasEmProducaoStream(
                              s.firestoreId, widget.user.teamId),
                          builder: (context, wipSnapshot) {
                            final producaoDia = prodSnapshot.data ?? 0;
                            final emProducao = wipSnapshot.data ?? 0;

                            return _SectorTile(
                              icon: IconData(s.iconCodePoint,
                                  fontFamily: 'MaterialIcons'),
                              nome: s.label,
                              producaoDia: producaoDia,
                              emProducao: emProducao,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _SectorDetailShell(
                                        sector: s, user: widget.user),
                                  ),
                                );
                              },
                              color: Color(s.colorValue),
                            );
                          },
                        );
                      },
                    );
                  },
                  childCount: sectorList.length,
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  void _showWorkInProgressBottomSheet(
      BuildContext context, List<Map<String, dynamic>> wipFichas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _WorkInProgressContent(
              wipFichas: wipFichas,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

// ====================================================================
// _SectorDetailShell (Página de Detalhe do Setor)
// ====================================================================

class _SectorDetailShell extends StatefulWidget {
  final ConfigurableSector sector;
  final AppUserModel user;
  const _SectorDetailShell({required this.sector, required this.user});

  @override
  State<_SectorDetailShell> createState() => _SectorDetailShellState();
}

class _SectorData {
  final int producaoDia;
  final int emPares;
  final List<Map<String, dynamic>> fichasAbertas;
  final List<Map<String, dynamic>> fichasFinalizadas;
  final List<Map<String, dynamic>> activeBottlenecks;

  _SectorData({
    required this.producaoDia,
    required this.emPares,
    required this.fichasAbertas,
    required this.fichasFinalizadas,
    required this.activeBottlenecks,
  });
}

class _SectorDetailShellState extends State<_SectorDetailShell> {
  final ProductionManager _pm = ProductionManager.instance;
  late Future<_SectorData> _sectorDataFuture;

  @override
  void initState() {
    super.initState();
    _sectorDataFuture = _loadSectorData();
  }

  @override
  void didUpdateWidget(covariant _SectorDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.teamId != widget.user.teamId) {
      _sectorDataFuture = _loadSectorData();
    }
  }

  Future<_SectorData> _loadSectorData() async {
    final sectorId = widget.sector.firestoreId;
    final teamId = widget.user.teamId;

    final results = await Future.wait([
      _pm.getProducaoDoDia(sectorId, teamId),
      _pm.getFichasEmProducao(sectorId, teamId),
      _pm.getOpenMovements(sectorId, teamId),
      _pm.getClosedMovements(sectorId, teamId),
      _pm.getActiveBottlenecksForSector(sectorId, teamId),
    ]);

    final fichasAbertas = (results[2] as List<Map<String, dynamic>>);
    final fichasFinalizadas = (results[3] as List<Map<String, dynamic>>);

    fichasAbertas.sort((a, b) => _compareTimestamps(b['inAt'], a['inAt']));
    fichasFinalizadas
        .sort((a, b) => _compareTimestamps(b['outAt'], a['outAt']));

    return _SectorData(
      producaoDia: results[0] as int,
      emPares: results[1] as int,
      fichasAbertas: fichasAbertas,
      fichasFinalizadas: fichasFinalizadas,
      activeBottlenecks: results[4] as List<Map<String, dynamic>>,
    );
  }

  int _compareTimestamps(dynamic a, dynamic b) {
    final da = _parseTimestamp(a);
    final db = _parseTimestamp(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  DateTime? _parseTimestamp(dynamic t) {
    if (t == null) return null;
    if (t is Timestamp) return t.toDate();
    if (t is String) return DateTime.tryParse(t);
    return null;
  }

  String _formatarDataDynamic(dynamic value) {
    final dt = _parseTimestamp(value);
    if (dt == null) return '??';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _resolveBottleneck(String id) async {
    try {
      await _pm.resolveBottleneck(bottleneckKey: id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gargalo resolvido')));
      setState(() {
        _sectorDataFuture = _loadSectorData();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao resolver: $e')));
    }
  }

  void _showCreateBottleneckDialog(BuildContext context) async {
    final pm = ProductionManager.instance;
    String? selectedReason;
    String customReason = '';
    String partName = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final showPartField = selectedReason == kMissingPartReason;
            final showCustomField = selectedReason == kOtherReason;

            return AlertDialog(
              title: Text('Criar Gargalo em ${widget.sector.label}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Motivo do Gargalo',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedReason,
                      items: pm.kBottleneckReasons.map((String reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          selectedReason = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (showPartField)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Qual peça está faltando?',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => partName = value.trim(),
                      ),
                    if (showCustomField)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Descreva o outro motivo',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => customReason = value.trim(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedReason == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Selecione um motivo.')));
                      return;
                    }
                    await pm.createBottleneck(
                      sectorId: widget.sector.firestoreId,
                      reason: selectedReason!,
                      teamId: widget.user.teamId,
                      customReason:
                          customReason.isNotEmpty ? customReason : null,
                      partName: partName.isNotEmpty ? partName : null,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Gargalo criado em ${widget.sector.label}!')));
                    setState(() {
                      _sectorDataFuture = _loadSectorData();
                    });
                  },
                  child: const Text('Registrar Gargalo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sector = widget.sector;

    return Scaffold(
      appBar: AppBar(title: Text('Setor: ${sector.label}')),
      body: FutureBuilder<_SectorData>(
        future: _sectorDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- ESTA É A MUDANÇA ---
          // Se tiver um erro, imprime no console para vermos o link do índice
          if (snapshot.hasError) {
            debugPrint("### ERRO AO CARREGAR DADOS DO SETOR: ###");
            debugPrint(snapshot.error.toString());
            debugPrint("#########################################");

            return Center(
                child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Erro ao carregar dados: ${snapshot.error}'),
            ));
          }
          // --- FIM DA MUDANÇA ---

          if (!snapshot.hasData) {
            return const Center(child: Text('Nenhum dado encontrado.'));
          }

          final data = snapshot.data!;
          final _producaoDia = data.producaoDia;
          final _emPares = data.emPares;
          final _fichasAbertas = data.fichasAbertas;
          final _fichasFinalizadas = data.fichasFinalizadas;
          final _activeBottlenecks = data.activeBottlenecks;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Produção do dia (pares)'),
                  subtitle: const Text('Pares finalizados hoje neste setor'),
                  trailing: Text('$_producaoDia',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Em produção (pares)'),
                  subtitle: Text(
                      '${_fichasAbertas.length} fichas abertas neste setor'),
                  trailing: Text('$_emPares',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Ler QR'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScannerPage(
                                sectorId: sector.firestoreId,
                                user: widget.user),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Gargalo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(
                          color: Colors.orange.shade800,
                        ),
                      ),
                      onPressed: () {
                        _showCreateBottleneckDialog(context);
                      },
                    ),
                  ),
                ],
              ),
              if (_activeBottlenecks.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Gargalos Ativos (${_activeBottlenecks.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(thickness: 1),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _activeBottlenecks.length,
                  itemBuilder: (context, index) {
                    final bottleneck = _activeBottlenecks[index];
                    String reason = bottleneck['reason'] ?? 'Desconhecido';
                    if (reason == kOtherReason) {
                      reason = bottleneck['customReason'] ?? 'Outros';
                    } else if (reason == kMissingPartReason) {
                      reason =
                          'Reposição de peça: ${bottleneck['partName'] ?? 'Não especificada'}';
                    }

                    return ListTile(
                      leading: Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade800),
                      title: Text(reason),
                      subtitle: Text(
                          'Iniciado em: ${_formatarDataDynamic(bottleneck['startedAt'])}'),
                      trailing: TextButton(
                        child: const Text('Resolver'),
                        onPressed: () => _resolveBottleneck(bottleneck['id']),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Fichas Abertas (${_fichasAbertas.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 1),
              if (_fichasAbertas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                      child: Text('Nenhuma ficha aberta.',
                          style: TextStyle(color: Colors.grey))),
                ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _fichasAbertas.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ficha = _fichasAbertas[index];
                  final pares = ficha['pairs'] ?? 0;
                  final ticketId = ficha['ticketId'] ?? '?';
                  final dataEntrada = _formatarDataDynamic(ficha['inAt']);

                  return ListTile(
                    leading: CircleAvatar(child: Text(pares.toString())),
                    title: Text('Ficha: $ticketId'),
                    subtitle: Text('Entrada: $dataEntrada'),
                    trailing: const Text('Pares'),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Histórico de Finalizadas (${_fichasFinalizadas.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 1),
              if (_fichasFinalizadas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                      child: Text('Nenhuma ficha finalizada encontrada.',
                          style: TextStyle(color: Colors.grey))),
                ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _fichasFinalizadas.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ficha = _fichasFinalizadas[index];
                  final pares = ficha['pairs'] ?? 0;
                  final ticketId = ficha['ticketId'] ?? '?';
                  final dataEntrada = _formatarDataDynamic(ficha['inAt']);
                  final dataSaida = _formatarDataDynamic(ficha['outAt']);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(pares.toString(),
                          style: TextStyle(color: Colors.green.shade900)),
                    ),
                    title: Text('Ficha: $ticketId'),
                    subtitle: Text('Entrada: $dataEntrada\nSaída: $dataSaida'),
                    isThreeLine: true,
                    trailing: const Text('Pares'),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.qr_code_scanner),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScannerPage(
              sectorId: sector.firestoreId,
              user: widget.user,
            ),
          ));
        },
      ),
    );
  }
}

// =========================================================================
// == Widgets de UI (Resumo, Tile, WIP, Banner)
// =========================================================================
class _ResumoGeral extends StatelessWidget {
  final int totalHoje;
  final ConfigurableSector? mainSector;
  final VoidCallback? onEdit;

  const _ResumoGeral(
      {required this.totalHoje,
      required this.mainSector,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF223147);
    final sectorLabel = mainSector?.label ?? 'Setor Não Encontrado';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assessment, size: 28, color: primary),
                  ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.black54),
                      onPressed: onEdit,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Produção diária ($sectorLabel)',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '$totalHoje',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: primary,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Text('pares',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectorTile extends StatelessWidget {
  final IconData icon;
  final String nome;
  final int producaoDia;
  final int emProducao;
  final VoidCallback onTap;
  final Color color;

  const _SectorTile({
    required this.icon,
    required this.nome,
    required this.producaoDia,
    required this.emProducao,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: bg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 26, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$producaoDia',
                style: const TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              const Text('Produção do dia (pares)',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Text('Em produção: $emProducao',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalBottleneckBanner extends StatelessWidget {
  final List<Map<String, dynamic>> bottlenecks;
  const _GlobalBottleneckBanner({required this.bottlenecks});

  @override
  Widget build(BuildContext context) {
    String bannerText;
    if (bottlenecks.length == 1) {
      final bottleneck = bottlenecks.first;
      final sectorName = _getSectorName(bottleneck['sectorId']);
      String reason = bottleneck['reason'];
      if (reason == kOtherReason) {
        reason = bottleneck['customReason'] ?? 'Outros';
      } else if (reason == kMissingPartReason) {
        reason =
            'Reposição de peça: ${bottleneck['partName'] ?? 'Não especificada'}';
      }
      bannerText = 'GARGALO ATIVO: $sectorName ($reason)';
    } else {
      bannerText =
          '${bottlenecks.length} GARGALOS ATIVOS! (Clique para ver a lista)';
    }

    return Container(
      color: Colors.red.shade800,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                bannerText,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkInProgressContent extends StatefulWidget {
  final List<Map<String, dynamic>> wipFichas;
  final ScrollController scrollController;

  const _WorkInProgressContent({
    required this.wipFichas,
    required this.scrollController,
  });

  get allSectors => null;

  @override
  State<_WorkInProgressContent> createState() => _WorkInProgressContentState();
}

class _WorkInProgressContentState extends State<_WorkInProgressContent> {
  final TextEditingController _searchController = TextEditingController();
  final ProductionManager _pm =
      ProductionManager.instance; // ADICIONAR ESTA LINHA
  List<Map<String, dynamic>> _filteredFichas = [];

  @override
  void initState() {
    super.initState();
    _filteredFichas = widget.wipFichas;
    _searchController.addListener(_filterFichas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WorkInProgressContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wipFichas != oldWidget.wipFichas) {
      _filterFichas();
    }
  }

  void _filterFichas() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFichas = widget.wipFichas;
      } else {
        _filteredFichas = widget.wipFichas.where((ficha) {
          final ticketId = ficha['ticketId']?.toString().toLowerCase() ?? '';
          final ticketData = ficha['ticketData'] as Map?;
          final cliente =
              ticketData?['cliente']?.toString().toLowerCase() ?? '';
          final modelo = ticketData?['modelo']?.toString().toLowerCase() ?? '';
          final pedido = ticketData?['pedido']?.toString().toLowerCase() ?? '';

          // USAR A FUNÇÃO GLOBAL _getSectorName QUE JÁ ACESSA O PM
          final sectorId = ficha['sector'] ?? kTransitSectorId;
          final sectorName =
              _getSectorName(sectorId).toLowerCase(); // USAR FUNÇÃO GLOBAL
          final inTransit = sectorId == kTransitSectorId;
          final transitText = inTransit ? 'transito trânsito' : '';

          return ticketId.contains(query) ||
              cliente.contains(query) ||
              modelo.contains(query) ||
              pedido.contains(query) ||
              sectorName.contains(query) ||
              transitText.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabeçalho com pesquisa
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sync, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fichas em Produção (${widget.wipFichas.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Buscar por ficha, cliente, modelo, pedido ou setor...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_filteredFichas.length} resultado(s) encontrado(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Lista de fichas
        Expanded(
          child: _filteredFichas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isEmpty
                              ? Icons.inventory_2_outlined
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Nenhuma ficha em produção'
                              : 'Nenhuma ficha encontrada',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tente buscar por:\n• ID da ficha\n• Nome do cliente\n• Modelo\n• Número do pedido\n• Nome do setor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredFichas.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildFichaTile(_filteredFichas[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFichaTile(Map<String, dynamic> ficha) {
    try {
      final ticketId = ficha['ticketId']?.toString() ?? 'SEM ID';
      final ticketData = ficha['ticketData'] as Map<String, dynamic>?;

      if (ticketData == null) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: Text('Ficha #$ticketId'),
            subtitle: const Text('Dados incompletos'),
          ),
        );
      }

      final sectorId = ficha['sector']?.toString() ?? kTransitSectorId;
      final inTransit = (sectorId == kTransitSectorId);

      // Buscar o último setor de origem quando estiver em trânsito
      final lastSectorId = ficha['lastSectorId']?.toString();
      final lastSectorName = lastSectorId != null
          ? _getSectorName(lastSectorId)
          : null; // USA FUNÇÃO GLOBAL

      String sectorDisplayText;
      if (inTransit && lastSectorName != null) {
        sectorDisplayText = 'Em Trânsito (de: $lastSectorName)';
      } else {
        sectorDisplayText = _getSectorName(sectorId); // USA FUNÇÃO GLOBAL
      }

      final cliente =
          ticketData['cliente']?.toString() ?? 'Cliente não informado';
      final modelo = ticketData['modelo']?.toString() ?? 'Modelo não informado';
      final pedido = ticketData['pedido']?.toString() ?? 'S/N';
      final pairs = ticketData['pairs'] ?? 0;

      return Card(
        key: ValueKey(ticketId),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: inTransit
              ? BorderSide(color: Colors.orange.shade300, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🎫 #$ticketId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        sectorDisplayText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: inTransit
                          ? Colors.orange.withOpacity(0.2)
                          : Theme.of(context).primaryColor.withOpacity(0.15),
                      avatar: Icon(
                        inTransit ? Icons.local_shipping : Icons.business,
                        size: 16,
                        color: inTransit
                            ? Colors.orange[700]
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cliente,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.checkroom, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        modelo,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Pedido: $pedido',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      '$pairs pares',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Erro ao construir card de ficha: $e');
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.red.shade50,
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: const Text('Erro ao carregar ficha'),
          subtitle: Text('$e'),
        ),
      );
    }
  }
}
