// tickets_page.dart (CORRIGIDO PARA PDF EM LOTE)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/ticket_model.dart';
import 'package:gestor_calcados_new/pages/ticket_details_page.dart';
import 'package:gestor_calcados_new/pages/report_summary_page.dart';
// Importe o PdfService e o PdfResult
import 'package:gestor_calcados_new/services/pdf_service.dart';

class TicketsPage extends StatefulWidget {
  final AppUserModel user;
  const TicketsPage({super.key, required this.user});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final Set<String> _selectedTicketIds = {};
  List<TicketModel> _allTickets = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isSelecting => _selectedTicketIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic maybeTs) {
    if (maybeTs == null) return '??';
    DateTime dt;
    if (maybeTs is Timestamp) {
      dt = maybeTs.toDate().toLocal();
    } else if (maybeTs is DateTime) {
      dt = maybeTs.toLocal();
    } else {
      try {
        dt = DateTime.parse(maybeTs.toString()).toLocal();
      } catch (_) {
        return maybeTs.toString();
      }
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _toggleSelection(String ticketId) {
    setState(() {
      if (_selectedTicketIds.contains(ticketId)) {
        _selectedTicketIds.remove(ticketId);
      } else {
        _selectedTicketIds.add(ticketId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTicketIds.clear();
    });
  }

  void _navigateToDetails(TicketModel ticket) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TicketDetailsPage(ticket: ticket),
    ));
  }

  void _processConsumptionReport() {
    final selectedTickets =
        _allTickets.where((t) => _selectedTicketIds.contains(t.id)).toList();

    if (selectedTickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma ficha selecionada.')),
      );
      return;
    }

    final Map<String, (double, List<String>)> combinedMap = {};
    for (final ticket in selectedTickets) {
      for (final est in ticket.materialsUsed) {
        final key = '${est.material}|${est.color}';
        if (combinedMap.containsKey(key)) {
          final existing = combinedMap[key]!;
          final newMeters = existing.$1 + est.meters;
          final newPieces =
              (existing.$2..addAll(est.pieceNames)).toSet().toList();
          combinedMap[key] = (newMeters, newPieces);
        } else {
          combinedMap[key] = (est.meters, List<String>.from(est.pieceNames));
        }
      }
    }

    final estimates = combinedMap.entries.map((entry) {
      final parts = entry.key.split('|');
      final data = entry.value;
      return MaterialEstimate(
        material: parts[0],
        color: parts[1],
        meters: data.$1,
        pieceNames: data.$2..sort(),
      );
    }).toList()
      ..sort((a, b) => a.material.compareTo(b.material));

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportSummaryPage(
        ticketIds: _selectedTicketIds.toList()..sort(),
        estimates: estimates,
      ),
    ));
    _clearSelection();
  }

  // =======================================================================
  // --- SEÇÃO MODIFICADA (LÓGICA DO PDF AGRUPADO) ---
  // ESTA É A VERSÃO CORRETA (SEM LOOP 'FOR')
  // =======================================================================
  Future<void> _processBatchPdf() async {
    final List<TicketModel> selectedTickets =
        _allTickets.where((t) => _selectedTicketIds.contains(t.id)).toList();

    if (selectedTickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma ficha selecionada.')),
      );
      return;
    }

    // Ordena pela data (usando lastMovedAt que sabemos que existe)
    selectedTickets.sort((a, b) {
      // Ordena do mais antigo para o mais novo
      return (a.lastMovedAt ?? Timestamp(0, 0))
          .compareTo(b.lastMovedAt ?? Timestamp(0, 0));
    });

    // --- MUDANÇA: LÓGICA DE PDF AGRUPADO ---
    // Agora chamamos a *nova* função no PdfService que
    // aceita a LISTA INTEIRA de fichas para criar um único PDF.

    String feedbackMessage;
    Color feedbackColor;

    try {
      // 1. CHAMA A FUNÇÃO DE LOTE (generateAndShareBatchPdf) UMA VEZ
      final PdfResult result =
          await PdfService.generateAndShareBatchPdf(selectedTickets);

      // 2. Processa o resultado único
      if (result.ok) {
        feedbackMessage = 'Sucesso! PDF agrupado compartilhado.';
        feedbackColor = Colors.green;
      } else {
        feedbackMessage = 'Falha ao gerar PDF: ${result.message}';
        debugPrint('Erro no PDF em lote: ${result.message}');
        feedbackColor = Colors.red;
      }
    } catch (e) {
      feedbackMessage = 'Erro inesperado: $e';
      debugPrint('Erro no PDF em lote: $e');
      feedbackColor = Colors.red;
    }
    // --- FIM DA MUDANÇA ---

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedbackMessage),
        backgroundColor: feedbackColor,
      ),
    );

    _clearSelection();
  }
  // =======================================================================
  // --- FIM DA SEÇÃO MODIFICADA ---
  // =======================================================================

  AppBar _buildAppBar() {
    if (_isSelecting) {
      return AppBar(
        title: Text('${_selectedTicketIds.length} selecionadas'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_outlined),
            tooltip: 'Somar Consumo',
            onPressed: _processConsumptionReport,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Gerar PDFs', // Nome do botão corrigido
            onPressed: _processBatchPdf,
          ),
        ],
      );
    } else {
      return AppBar(title: const Text('Fichas Salvas'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // --- Verificação do teamId (Manter para debug) ---
    // ============================================================
    if (kDebugMode) {
      print('===================================================');
      print('CONSULTANDO FICHAS PARA O teamId: ${widget.user.teamId}');
      print('===================================================');
    }
    // ============================================================

    // ============================================================
    // --- ALTERAÇÃO 1: Consulta usa 'lastMovedAt' ---
    // ============================================================
    // ATENÇÃO: Verifique se você criou o índice no Firebase:
    // Coleção: 'tickets', Campo 1: 'teamId' (Crescente), Campo 2: 'lastMovedAt' (Decrescente)
    // ============================================================
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream =
        FirebaseFirestore.instance
            .collection('tickets')
            .where('teamId', isEqualTo: widget.user.teamId)
            .orderBy('lastMovedAt', descending: true) // <-- CORRIGIDO AQUI
            .snapshots();

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar Fichas',
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
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  if (kDebugMode) {
                    print('!!!!!!!! ERRO NO STREAMBUILDER !!!!!!!!');
                    print(snap.error);
                    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
                  }
                  return Center(child: Text('Erro: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                _allTickets =
                    docs.map((d) => TicketModel.fromFirestore(d)).toList();

                final query = _searchQuery.toLowerCase().trim();
                final filteredTickets = query.isEmpty
                    ? _allTickets
                    : _allTickets.where((t) {
                        return (t.id.toLowerCase().contains(query) ||
                            t.cliente.toLowerCase().contains(query) ||
                            t.productName.toLowerCase().contains(query) ||
                            t.productReference.toLowerCase().contains(query) ||
                            t.productColor.toLowerCase().contains(query) ||
                            t.pedido.toLowerCase().contains(query));
                      }).toList();

                if (filteredTickets.isEmpty) {
                  return Center(
                    child: Text(_allTickets.isEmpty
                        ? 'Nenhuma ficha encontrada.'
                        : 'Nenhum resultado para "$_searchQuery".'),
                  );
                }

                return ListView.separated(
                  itemCount: filteredTickets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = filteredTickets[index];

                    // ============================================================
                    // --- ALTERAÇÃO 2: Subtítulo usa 'lastMovedAt' ---
                    // ============================================================
                    final subtitle = (t.cliente.isNotEmpty
                            ? '${t.cliente} • '
                            : '') +
                        _formatTimestamp(t.lastMovedAt); // <-- CORRIGIDO AQUI

                    final isSelected = _selectedTicketIds.contains(t.id);

                    return ListTile(
                      leading: CircleAvatar(child: Text(t.pairs.toString())),
                      title: Text('${t.id} • ${t.productName}'),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withOpacity(0.1),
                      onTap: () {
                        if (_isSelecting) {
                          _toggleSelection(t.id);
                        } else {
                          _navigateToDetails(t);
                        }
                      },
                      onLongPress: () => _toggleSelection(t.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
