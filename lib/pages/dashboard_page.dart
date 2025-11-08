import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/data/material_repository.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Imports das suas páginas
import 'create_ticket_page.dart';
import 'tickets_page.dart';
import 'scanner_page.dart';
import 'product_form_page.dart';
import 'product_list_page.dart';
import 'report_page.dart';

// --- NOVOS IMPORTS (MATERIAIS) ---
// (Agora ativados!)
import 'material_form_page.dart';
import 'material_list_page.dart';
// ------------------------------------

// Import do modelo oficial
import '../models/sector_models.dart';
// Import do repositório de materiais (necessário para o init)

// Import do ProductionManager (integração Hive + regras)
import '../services/production_manager.dart' hide kTransitSectorId;
// --- NOVO IMPORT PARA O BACKUP ---
import '../services/backup_service.dart';
// ---------------------------------

// Boxes usadas pelo scanner / produção
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';
// --- ADICIONADO PARA GARGALOS ---
const String kBottlenecksActiveBox = 'bottlenecks_active_box';
// ---------------------------------

// --- Constantes de Motivo de Gargalo (para a UI) ---
// (Movido para cá para ser acessível por todos os widgets no arquivo)
const String kMissingPartReason = 'Reposição de peça'; // <-- TEXTO ALTERADO
const String kOtherReason = 'Outros (especificar)';
// ------------------------------------------------

// --- ENUM DO SEMÁFORO REMOVIDO ---

// ---------- Utils (com espaços corrigidos) ----------
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _getProductionToday(Box dailyBox, String sectorFirestoreId) {
  final key = '$sectorFirestoreId::${_ymd(DateTime.now())}';
  return (dailyBox.get(key) as int?) ?? 0;
}

// Lógica de "Em Produção" somando PARES (fallback - com espaços corrigidos)
int _getInProcessNow(Box movBox, String sectorFirestoreId) {
  int totalPares = 0;
  for (final k in movBox.keys) {
    if (k is String &&
        k.startsWith('open::') &&
        k.endsWith('::$sectorFirestoreId')) {
      final movement = movBox.get(k) as Map?;
      if (movement != null) {
        totalPares += (movement['pairs'] as int?) ?? 0;
      }
    }
  }
  return totalPares;
}

// --- ATUALIZADO: Helper para pegar nome do setor (com "Em Trânsito") ---
String _getSectorName(String sectorId) {
  // Adiciona a verificação para o status kTransitSectorId
  if (sectorId == kTransitSectorId) {
    return 'Em Trânsito';
  }
  try {
    return Sector.values.firstWhere((s) => s.firestoreId == sectorId).label;
  } catch (_) {
    return sectorId; // Fallback
  }
}

// --- ADICIONADO: Helper para pegar o Enum do setor ---
Sector? _getSectorFromId(String sectorId) {
  try {
    return Sector.values.firstWhere((s) => s.firestoreId == sectorId);
  } catch (_) {
    return null; // Fallback
  }
}
// ====================================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _openBoxes();
  }

  Future<void> _openBoxes() async {
    if (!Hive.isBoxOpen(kMovementsBox)) {
      await Hive.openBox(kMovementsBox);
    }
    if (!Hive.isBoxOpen(kSectorDailyBox)) {
      await Hive.openBox(kSectorDailyBox);
    }
    // --- ABRE A BOX DE GARGALO ---
    if (!Hive.isBoxOpen(kBottlenecksActiveBox)) {
      await Hive.openBox(kBottlenecksActiveBox);
    }
    // ---------------------------------

    // ### ATIVADO: INICIALIZA O REPOSITÓRIO DE MATERIAIS ###
    // Isso garante que a 'materials_box' esteja aberta
    // antes que qualquer página tente usá-la.
    await MaterialRepository().init();
    // #######################################################

    try {
      // 2. CORREÇÃO: Usar ProductionManager.instance
      await ProductionManager.instance.initHiveBoxes(
        eventsBox: Hive.box(kMovementsBox),
        countersBox: Hive.box(kSectorDailyBox),
      );
    } catch (e) {
      // print('ProductionManager init failed: $e');
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daily =
        Hive.isBoxOpen(kSectorDailyBox) ? Hive.box(kSectorDailyBox) : null;
    final movs = Hive.isBoxOpen(kMovementsBox) ? Hive.box(kMovementsBox) : null;

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // <<< CABEÇALHO SIMPLES (Opção 2) >>>
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0,
                  20.0), // Ajuste o padding (top 50, bottom 20)
              child: Text(
                'Menu Principal', // Título MantIDO
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            // <<< FIM DA ALTERAÇÃO DO CABEÇALHO >>>

            // Itens do Menu (iguais)
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Criar Nova Ficha'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateTicketPage(),
                  fullscreenDialog: true,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Ver Fichas Salvas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TicketsPage(),
                  fullscreenDialog: true,
                ));
              },
            ),

            // --- BOTÃO DE RELATÓRIO ADICIONADO ---
            ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('Relatório de Produção'),
              onTap: () {
                Navigator.pop(context); // Fecha o Drawer
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ReportPage(),
                ));
              },
            ),
            // --- FIM DA ADIÇÃO ---

            // --- NOVO BOTÃO DE BACKUP ADICIONADO ---
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup de Dados'),
              onTap: () {
                Navigator.pop(context); // Fecha o Drawer
                // Chama o serviço de backup
                BackupService.generateBackup(context);
              },
            ),
            // --- FIM DA ADIÇÃO ---

            // --- NOVO BOTÃO DE RESTAURAR ADICIONADO ---
            ListTile(
              leading: const Icon(Icons.settings_backup_restore_outlined),
              title: const Text('Restaurar Backup'),
              onTap: () {
                Navigator.pop(context); // Fecha o Drawer
                // Chama o serviço de restauração
                BackupService.restoreBackup(context);
              },
            ),
            // --- FIM DA ADIÇÃO ---

            const Divider(), // Divisor para separar as seções

            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Cadastrar Novo Produto'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductFormPage(),
                  fullscreenDialog: true,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Ver Produtos Cadastrados'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductListPage(),
                ));
              },
            ),

            // --- NOVA SEÇÃO DE MATERIAIS (LÓGICA ATIVADA) ---
            const Divider(), // Divisor para a nova seção

            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Cadastrar Novo Material'),
              onTap: () {
                Navigator.pop(context);
                // ATIVADO: Navega para o formulário
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MaterialFormPage(),
                  fullscreenDialog: true,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Ver Materiais Cadastrados'),
              onTap: () {
                Navigator.pop(context);
                // ATIVADO: Navega para a lista
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MaterialListPage(),
                ));
              },
            ),
            // --- FIM DA NOVA SEÇÃO ---
          ],
        ),
      ),
      // --- APPBAR ATUALIZADA ---
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColorDark, // Usa as cores do tema
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
            color: Colors.white, // Garante texto branco
          ),
        ),
        iconTheme: const IconThemeData(
            color: Colors.white), // Deixa o ícone do menu branco
        actions: const [], // Sem actions
      ),
      // --- FIM DA ATUALIZAÇÃO ---
      body: SafeArea(
        bottom: true,
        top: false,
        child: !_ready || daily == null || movs == null
            ? const Center(child: CircularProgressIndicator())
            : _DashboardBody(dailyBox: daily, movBox: movs),
      ),
      floatingActionButton: null, // Sem botões flutuantes
    );
  }
}

// O restante do código (_DashboardBody, _ResumoGeral, _SectorTile, _SectorDetailShell)
class _DashboardBody extends StatelessWidget {
  final Box dailyBox;
  final Box movBox;

  const _DashboardBody({required this.dailyBox, required this.movBox});

  // --- ATUALIZADO: O diálogo que lista TODOS os gargalos (Layout Corrigido) ---
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

                // Lógica para mostrar o motivo (com "Outros" e "Peça")
                String reason = bottleneck['reason'];
                if (reason == kOtherReason) {
                  reason = bottleneck['customReason'] ?? 'Outros';
                } else if (reason == kMissingPartReason) {
                  reason =
                      'Reposição de peça: ${bottleneck['partName'] ?? 'Não especificada'}';
                }

                // --- CORREÇÃO DE LAYOUT DO LISTTILE ---
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  leading: Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade800),
                  title: Text(sectorName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  // O Subtitle agora é uma Coluna com o motivo e o botão
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(reason), // Descrição com largura total
                      const SizedBox(height: 8),
                      // Alinha o botão à direita
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Resolver'),
                          onPressed: () {
                            ProductionManager.instance.resolveBottleneck(
                                bottleneckKey: bottleneck['id']);
                            Navigator.of(context).pop(); // Fecha o diálogo
                          },
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navega para o setor
                    final sector = _getSectorFromId(sectorId);
                    if (sector != null) {
                      Navigator.of(context).pop(); // Fecha o diálogo
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _SectorDetailShell(sector: sector),
                        ),
                      );
                    }
                  },
                );
                // --- FIM DA CORREÇÃO DE LAYOUT ---
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

  // --- ATUALIZADO: Diálogo para mostrar as Fichas Abertas (WIP) com Pesquisa ---
  void _showWipFichasDialog(
      BuildContext context, List<Map<String, dynamic>> wipFichas) {
    // Variáveis para controlar o estado do diálogo
    String searchQuery = '';
    List<Map<String, dynamic>> filteredFichas = List.from(wipFichas);
    // Controller para limpar o texto
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder é necessário para atualizar o estado do diálogo (a lista filtrada)
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Fichas em Produção (${filteredFichas.length})'),
              // Remove o padding padrão para a lista encostar
              contentPadding: const EdgeInsets.only(top: 20.0, bottom: 0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- BARRA DE PESQUISA ADICIONADA ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          // Filtra a lista
                          setStateDialog(() {
                            searchQuery = value.toLowerCase();
                            filteredFichas = wipFichas.where((ficha) {
                              final ticketId =
                                  (ficha['ticketId'] ?? '').toLowerCase();
                              return ticketId.contains(searchQuery);
                            }).toList();
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Pesquisar por Ficha',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    // Limpa o controller e atualiza o estado
                                    searchController.clear();
                                    setStateDialog(() {
                                      searchQuery = '';
                                      filteredFichas = wipFichas;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- FIM DA BARRA DE PESQUISA ---

                    // --- LISTA DE FICHAS ---
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            filteredFichas.length, // Usa a lista filtrada
                        itemBuilder: (context, index) {
                          final ficha =
                              filteredFichas[index]; // Usa a lista filtrada

                          // --- ATUALIZADO: Mostra "Em Trânsito" ---
                          final bool isTransit =
                              ficha['sector'] == kTransitSectorId;
                          final sectorName = _getSectorName(ficha['sector']);
                          // -----------------------------------------

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            leading: Icon(
                              // Mostra ícone diferente para "Em Trânsito"
                              isTransit
                                  ? Icons.compare_arrows_outlined
                                  : Icons.sync,
                              color: isTransit
                                  ? Colors.grey[700]
                                  : Theme.of(context).primaryColor,
                            ),
                            title: Text('Ficha: ${ficha['ticketId']}'),
                            subtitle:
                                Text(sectorName), // Já mostra "Em Trânsito"
                            trailing: Text('${ficha['pairs']} pares'),
                            onTap: () {
                              // Não deixa clicar se estiver "Em Trânsito"
                              if (isTransit) return;

                              // Navega para o setor
                              final sector = _getSectorFromId(ficha['sector']);
                              if (sector != null) {
                                Navigator.of(context).pop(); // Fecha o diálogo
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _SectorDetailShell(sector: sector),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                    // --- FIM DA LISTA ---
                  ],
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
      },
    );
  }
  // --- FIM DO DIÁLOGO WIP ---

  @override
  Widget build(BuildContext context) {
    // --- ADICIONADO: Pega a box de gargalos ---
    final bottleneckBox = Hive.box(kBottlenecksActiveBox);

    final merged = Listenable.merge([
      dailyBox.listenable(),
      movBox.listenable(),
      bottleneckBox.listenable(), // <-- Escuta a nova box
    ]);

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        // --- ADICIONADO: Pega todos os gargalos 1 vez ---
        final allActiveBottlenecks =
            ProductionManager.instance.getAllActiveBottlenecks();

        final tiles = Sector.values.map((s) {
          // 2. CORREÇÃO: Usar ProductionManager.instance
          final pm = ProductionManager.instance;
          int producaoDia;
          int emProducao;
          try {
            producaoDia = pm.getProducaoDoDia(s.firestoreId);
            emProducao = pm.getFichasEmProducao(s.firestoreId);
          } catch (_) {
            // fallback para o comportamento anterior caso PM não esteja inicializado
            producaoDia = _getProductionToday(dailyBox, s.firestoreId);
            emProducao = _getInProcessNow(movBox, s.firestoreId);
          }

          // --- LÓGICA DO SEMÁFORO REMOVIDA ---

          return _SectorTile(
            icon: s.icon,
            nome: s.label,
            producaoDia: producaoDia,
            emProducao: emProducao,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _SectorDetailShell(sector: s),
                ),
              );
            },
            // --- NOVO: Passa a cor para o Card ---
            color: s.color,
            // ------------------------------------
          );
        }).toList();

        // Total da Montagem
        // 2. CORREÇÃO: Usar ProductionManager.instance
        final totalHoje = ProductionManager.instance
            .getProducaoDoDia(Sector.montagem.firestoreId);

        // --- ADICIONADO (SUGESTÃO 3): Pega as fichas WIP ---
        final activeWipFichas =
            ProductionManager.instance.getAllWorkInProgressFichas();

        // --- CORREÇÃO DE LAYOUT: Troca Column/ListView por CustomScrollView/Slivers ---
        return CustomScrollView(
          slivers: [
            // --- Banner de Alerta ---
            if (allActiveBottlenecks.isNotEmpty) // <-- Usa a variável local
              SliverToBoxAdapter(
                child: InkWell(
                  onTap: () {
                    // Chama o novo diálogo
                    _showActiveBottlenecksDialog(context, allActiveBottlenecks);
                  },
                  child: _GlobalBottleneckBanner(
                      bottlenecks: allActiveBottlenecks),
                ),
              ),

            // --- Resumo Geral ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _ResumoGeral(totalHoje: totalHoje),
              ),
            ),

            // --- Painel WIP (AGORA CLICÁVEL) ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _WorkInProgressPanel(
                  wipFichas: activeWipFichas,
                  onTap: () {
                    // Chama o novo diálogo de WIP
                    _showWipFichasDialog(context, activeWipFichas);
                  },
                ),
              ),
            ),

            // --- Título "Visão por Setor" ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                child: Text(
                  'Visão por Setor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // --- Grid de Setores ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Travado em 2 colunas
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.87,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => tiles[index],
                  childCount: tiles.length,
                ),
              ),
            ),

            // --- Espaçador no final ---
            SliverToBoxAdapter(
              child: const SizedBox(height: 20),
            ),
          ],
        );
        // --- FIM DA CORREÇÃO DE LAYOUT ---
      },
    );
  }
}

// ---------- Widgets do dashboard (com espaços corrigidos) ----------
class _ResumoGeral extends StatelessWidget {
  final int totalHoje;
  const _ResumoGeral({required this.totalHoje});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF223147);
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primary.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.assessment, size: 28, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Produção diária (Montagem)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$totalHoje',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
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
          ],
        ),
      ),
    );
  }
}

// --- ATUALIZADO: _SectorTile agora aceita cor E STATUS ---
class _SectorTile extends StatelessWidget {
  final IconData icon;
  final String nome;
  final int producaoDia;
  final int emProducao;
  final VoidCallback onTap;
  final Color color; // <-- NOVO: Parâmetro de cor

  // --- PARÂMETRO STATUS REMOVIDO ---
  const _SectorTile({
    required this.icon,
    required this.nome,
    required this.producaoDia,
    required this.emProducao,
    required this.onTap,
    required this.color, // <-- NOVO: Parâmetro de cor
  });

  @override
  Widget build(BuildContext context) {
    // const bg = Color(0xFF223147); <-- Antiga cor fixa
    final bg = color; // <-- USA A COR DO SETOR

    // --- ATUALIZADO: Stack removido ---
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
    // --- FIM DA ATUALIZAÇÃO ---
  }
}

// ---------- Detalhe simples interno (com espaços corrigidos) ----------
class _SectorDetailShell extends StatelessWidget {
  final Sector sector;
  const _SectorDetailShell({required this.sector});

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatarData(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '??';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  // --- ATUALIZADO: DIÁLOGO PARA CRIAR GARGALO (COM CAMPO DE PEÇA) ---
  void _showCreateBottleneckDialog(BuildContext context) {
    // Usamos um StatefulBuilder para gerenciar o estado do diálogo
    showDialog(
      context: context,
      builder: (dialogContext) {
        String selectedReason =
            ProductionManager.instance.kBottleneckReasons.first;
        String customReason = '';
        String partName = ''; // <-- NOVO: Armazena o nome da peça
        bool showCustomField = false;
        bool showPartNameField = false; // <-- NOVO: Controla o campo de peça

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Gargalo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gera a lista de opções de rádio
                    ...ProductionManager.instance.kBottleneckReasons
                        .map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) {
                          if (value == null) return;
                          setStateDialog(() {
                            selectedReason = value;
                            // ATUALIZADO: Controla os campos extras
                            showCustomField = (value == kOtherReason);
                            showPartNameField = (value == kMissingPartReason);
                          });
                        },
                      );
                    }).toList(),

                    // NOVO: Campo de texto para "Peça Faltando"
                    if (showPartNameField)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 8.0, left: 16, right: 16),
                        child: TextField(
                          onChanged: (value) => partName = value,
                          decoration: const InputDecoration(
                            labelText: 'Qual peça está faltando?',
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                      ),

                    // Campo de texto para "Outros"
                    if (showCustomField)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 8.0, left: 16, right: 16),
                        child: TextField(
                          onChanged: (value) => customReason = value,
                          decoration: const InputDecoration(
                            labelText: 'Especifique o motivo',
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FilledButton(
                  child: const Text('Confirmar'),
                  onPressed: () {
                    // Validação para "Outros"
                    if (showCustomField && customReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Por favor, especifique o motivo em "Outros"')),
                      );
                      return;
                    }
                    // NOVO: Validação para "Peça"
                    if (showPartNameField && partName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Por favor, especifique a peça que está faltando')),
                      );
                      return;
                    }

                    // ATUALIZADO: Chama o ProductionManager com todos os dados
                    ProductionManager.instance.createBottleneck(
                      sectorId: sector.firestoreId,
                      reason: selectedReason,
                      customReason: showCustomField ? customReason : null,
                      partName: showPartNameField ? partName : null,
                    );
                    Navigator.of(context).pop();
                  },
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
    final daily = Hive.box(kSectorDailyBox);
    final movs = Hive.box(kMovementsBox);
    // --- ADICIONADO: Pega a box de gargalos ---
    final bottlenecks = Hive.box(kBottlenecksActiveBox);

    // --- Funções locais ---
    int producaoDia() {
      try {
        // 2. CORREÇÃO: Usar ProductionManager.instance
        return ProductionManager.instance.getProducaoDoDia(sector.firestoreId);
      } catch (_) {
        final key = '${sector.firestoreId}::${_ymd(DateTime.now())}';
        return (daily.get(key) as int?) ?? 0;
      }
    }

    int emProducaoSomaPares() {
      try {
        // 2. CORREÇÃO: Usar ProductionManager.instance
        return ProductionManager.instance
            .getFichasEmProducao(sector.firestoreId);
      } catch (_) {
        int totalPares = 0;
        for (final k in movs.keys) {
          if (k is String &&
              k.startsWith('open::') &&
              k.endsWith('::${sector.firestoreId}')) {
            final movement = movs.get(k) as Map?;
            if (movement != null) {
              totalPares += (movement['pairs'] as int?) ?? 0;
            }
          }
        }
        return totalPares;
      }
    }

    List<Map> _getFichasAbertas() {
      final List<Map> fichas = [];
      for (final k in movs.keys) {
        if (k is String &&
            k.startsWith('open::') &&
            k.endsWith('::${sector.firestoreId}')) {
          final movement = movs.get(k) as Map?;
          if (movement != null) {
            fichas.add(Map.from(movement));
          }
        }
      }
      fichas
          .sort((a, b) => (b['inAt'] as String).compareTo(a['inAt'] as String));
      return fichas;
    }

    List<Map> _getFichasFinalizadasNoSetor() {
      final List<Map> finalizadas = [];
      for (final key in movs.keys) {
        if (key is String && key.startsWith('hist::')) {
          final histList = movs.get(key) as List?;
          if (histList != null) {
            for (final movement in histList) {
              if (movement is Map) {
                if (movement['sector'] == sector.firestoreId &&
                    movement['outAt'] != null) {
                  finalizadas.add(Map.from(movement));
                }
              }
            }
          }
        }
      }
      finalizadas.sort(
          (a, b) => (b['outAt'] as String).compareTo(a['outAt'] as String));
      return finalizadas;
    }
    // --- Fim das funções ---

    final listenable = Listenable.merge([
      daily.listenable(),
      movs.listenable(),
      bottlenecks.listenable(), // <-- ADICIONADO: Escuta a box de gargalos
    ]);

    return Scaffold(
      appBar: AppBar(title: Text('Setor: ${sector.label}')),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final prod = producaoDia();
          final emPares = emProducaoSomaPares();
          final fichasAbertas = _getFichasAbertas();
          final fichasFinalizadas = _getFichasFinalizadasNoSetor();

          // --- ATUALIZADO: Pega a LISTA de gargalos ---
          final activeBottlenecks = ProductionManager.instance
              .getActiveBottlenecksForSector(sector.firestoreId);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Produção do dia (pares)'),
                  subtitle: const Text('Pares finalizados hoje neste setor'),
                  trailing: Text('$prod',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Em produção (pares)'),
                  subtitle: Text(
                      '${fichasAbertas.length} fichas abertas neste setor'),
                  trailing: Text('$emPares',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 16),

              // --- ATUALIZADO: Row para os botões ---
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Ler QR'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  ScannerPage(sectorId: sector.firestoreId)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // --- ATUALIZADO: Botão "Gargalo" é permanente ---
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
                        // Sempre abre o diálogo de CRIAR
                        _showCreateBottleneckDialog(context);
                      },
                    ),
                  ),
                ],
              ),
              // --- FIM DA MUDANÇA ---

              // --- ADICIONADO: Lista de Gargalos Ativos no Setor ---
              if (activeBottlenecks.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Gargalos Ativos (${activeBottlenecks.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(thickness: 1),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: activeBottlenecks.length,
                  itemBuilder: (context, index) {
                    final bottleneck = activeBottlenecks[index];

                    // Lógica para mostrar o motivo (com "Outros" e "Peça")
                    String reason = bottleneck['reason'];
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
                          'Iniciado em: ${_formatarData(bottleneck['startedAt'])}'),
                      trailing: TextButton(
                        child: const Text('Resolver'),
                        onPressed: () {
                          // --- ESTA É A CORREÇÃO PARA A "TRAVADINHA" ---
                          // Nós passamos a "chave" (id) do gargalo
                          ProductionManager.instance.resolveBottleneck(
                            bottleneckKey: bottleneck['id'],
                          );
                          // ----------------------------------------------
                        },
                      ),
                    );
                  },
                ),
              ],
              // --- FIM DA ADIÇÃO ---

              // --- Lista de Fichas Abertas ---
              const SizedBox(height: 24),
              Text(
                'Fichas Abertas (${fichasAbertas.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 1),
              if (fichasAbertas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                      child: Text('Nenhuma ficha aberta.',
                          style: TextStyle(color: Colors.grey))),
                ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: fichasAbertas.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ficha = fichasAbertas[index];
                  final pares = ficha['pairs'] ?? 0;
                  final ticketId = ficha['ticketId'] ?? '?';
                  final dataEntrada = _formatarData(ficha['inAt']);

                  return ListTile(
                    leading: CircleAvatar(child: Text(pares.toString())),
                    title: Text('Ficha: $ticketId'),
                    subtitle: Text('Entrada: $dataEntrada'),
                    trailing: const Text('Pares'),
                  );
                },
              ),

              // --- Lista de Fichas Finalizadas ---
              const SizedBox(height: 24),
              Text(
                'Histórico de Finalizadas (${fichasFinalizadas.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 1),
              if (fichasFinalizadas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                      child: Text('Nenhuma ficha finalizada encontrada.',
                          style: TextStyle(color: Colors.grey))),
                ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: fichasFinalizadas.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ficha = fichasFinalizadas[index];
                  final pares = ficha['pairs'] ?? 0;
                  final ticketId = ficha['ticketId'] ?? '?';
                  final dataEntrada = _formatarData(ficha['inAt']);
                  final dataSaida = _formatarData(ficha['outAt']);

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
    );
  }
}

// --- ATUALIZADO (SUGESTÃO 3): Painel WIP agora é clicável ---
class _WorkInProgressPanel extends StatelessWidget {
  final List<Map<String, dynamic>> wipFichas;
  final VoidCallback onTap; // <-- NOVO: Callback
  const _WorkInProgressPanel({required this.wipFichas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 2,
      child: ListTile(
        // <-- MUDANÇA: Substituído ExpansionTile por ListTile
        leading: Icon(Icons.sync, color: Theme.of(context).primaryColor),
        title: Text(
          'Fichas em Produção (${wipFichas.length})', // <-- MUDANÇA: "(WIP)" removido
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Clique para ver a lista de fichas abertas'),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16), // <-- MUDANÇA: Ícone
        onTap: onTap, // <-- MUDANÇA: Chama o callback
      ),
    );
  }
}

// --- ATUALIZADO: WIDGET DO BANNER DE ALERTA GLOBAL (VERMELHO E COM ÍCONE) ---
class _GlobalBottleneckBanner extends StatelessWidget {
  final List<Map<String, dynamic>> bottlenecks;
  const _GlobalBottleneckBanner({required this.bottlenecks});

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DO TEXTO ATUALIZADA ---
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
    // --- FIM DA LÓGICA ---

    return Container(
      color: Colors.red.shade800, // <-- MMUDANÇA: Cor para vermelho
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          // <-- MUDANÇA: Adicionado Row
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              // <-- MUDANÇA: Adicionado Ícone
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              // <-- MUDANÇA: Adicionado Flexible
              child: Text(
                bannerText, // <-- Usa o novo texto
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis, // Evita quebra de linha feia
              ),
            ),
          ],
        ),
      ),
    );
  }
}
