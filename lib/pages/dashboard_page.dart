// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Imports das suas páginas
import 'create_ticket_page.dart';
import 'tickets_page.dart';
import 'scanner_page.dart';
import 'product_form_page.dart';
import 'product_list_page.dart';

// Import do modelo oficial
import '../models/sector_models.dart';

// Boxes usadas pelo scanner / produção
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';

// ---------- Utils ----------
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _getProductionToday(Box dailyBox, String sectorFirestoreId) {
  final key = '$sectorFirestoreId::${_ymd(DateTime.now())}';
  return (dailyBox.get(key) as int?) ?? 0;
}

// Lógica de "Em Produção" somando PARES
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
                'Menu Principal', // Título Mantido
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      // Você pode adicionar uma cor se quiser:
                      // color: Color(0xFF223147),
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
          ],
        ),
      ),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.fitWidth,
          child: Text('Bem-vindo à sua produção 👟'),
        ),
        actions: const [], // Sem actions
      ),
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
// permanece EXATAMENTE IGUAL ao último. Cole a partir daqui...
class _DashboardBody extends StatelessWidget {
  final Box dailyBox;
  final Box movBox;

  const _DashboardBody({required this.dailyBox, required this.movBox});

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([
      dailyBox.listenable(),
      movBox.listenable(),
    ]);

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        final tiles = Sector.values.map((s) {
          final producaoDia = _getProductionToday(dailyBox, s.firestoreId);
          final emProducao = _getInProcessNow(movBox, s.firestoreId);

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
          );
        }).toList();

        // Total da Montagem
        final totalHoje =
            _getProductionToday(dailyBox, Sector.montagem.firestoreId);

        return Column(
          children: [
            const SizedBox(height: 12),
            _ResumoGeral(totalHoje: totalHoje),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final cross = c.maxWidth >= 900 ? 3 : 2;
                  return GridView.builder(
                    cacheExtent: 600,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.87,
                    ),
                    itemCount: tiles.length,
                    itemBuilder: (_, i) => tiles[i],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------- Widgets do dashboard ----------
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

class _SectorTile extends StatelessWidget {
  final IconData icon;
  final String nome;
  final int producaoDia;
  final int emProducao;
  final VoidCallback onTap;

  const _SectorTile({
    required this.icon,
    required this.nome,
    required this.producaoDia,
    required this.emProducao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF223147);
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

// ---------- Detalhe simples interno (com histórico completo) ----------
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

  @override
  Widget build(BuildContext context) {
    final daily = Hive.box(kSectorDailyBox);
    final movs = Hive.box(kMovementsBox);

    // --- Funções locais ---
    int producaoDia() {
      final key = '${sector.firestoreId}::${_ymd(DateTime.now())}';
      return (daily.get(key) as int?) ?? 0;
    }

    int emProducaoSomaPares() {
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

    final listenable =
        Listenable.merge([daily.listenable(), movs.listenable()]);

    return Scaffold(
      appBar: AppBar(title: Text('Setor: ${sector.label}')),
      body: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final prod = producaoDia();
          final emPares = emProducaoSomaPares();
          final fichasAbertas = _getFichasAbertas();
          final fichasFinalizadas = _getFichasFinalizadasNoSetor();

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
              FilledButton.icon(
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
