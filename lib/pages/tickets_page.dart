import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'package:gestor_calcados_new/models/ticket.dart';
import 'package:gestor_calcados_new/pages/ticket_details_page.dart';
import 'package:gestor_calcados_new/services/ticket_pdf_service.dart';

// --- NOVOS IMPORTS ADICIONADOS ---
import 'package:gestor_calcados_new/pages/report_summary_page.dart';
import 'package:gestor_calcados_new/models/product.dart'; // Para MaterialEstimate
// Mantemos o import para o FAB, se necessário, ou usamos na página de resumo
// ---------------------------------

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final Set<String> _selectedIds = {};
  bool _isLoading = false;
  List<Ticket> _allTickets = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _navigateToDetails(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketDetailsPage(ticket: ticket),
      ),
    );
  }

  Future<void> _generateBatchPdf() async {
    setState(() => _isLoading = true);

    final selectedTickets =
        _allTickets.where((t) => _selectedIds.contains(t.id)).toList();

    if (selectedTickets.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await TicketPdfService.generateBatchPdf(selectedTickets);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
      _selectedIds.clear();
    });
  }

  // --- FUNÇÃO PARA CALCULAR E NAVEGAR PARA VISUALIZAÇÃO (CORREÇÃO DE FLUXO) ---
  Future<void> _onGenerateAndNavigateToReport() async {
    setState(() => _isLoading = true);

    final selectedTickets =
        _allTickets.where((t) => _selectedIds.contains(t.id)).toList();

    if (selectedTickets.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // 1. Agregação (soma) do Consumo
    final ticketIds = selectedTickets.map((t) => t.id).toList()..sort();
    final Map<String, (double, Set<String>)> summary = {};

    for (final ticket in selectedTickets) {
      if (ticket.materialsUsed.isEmpty) continue;

      for (final estimate in ticket.materialsUsed) {
        final key = '${estimate.material}||${estimate.color}';
        final current = summary[key] ?? (0.0, <String>{});

        final newMeters = current.$1 + estimate.meters;
        final newPieces = current.$2..addAll(estimate.pieceNames);

        summary[key] = (newMeters, newPieces);
      }
    }

    // 2. Converte o Mapa de resumo para a lista final de MaterialEstimate
    final List<MaterialEstimate> finalReport = [];
    final List<MapEntry<String, (double, Set<String>)>> sortedSummary =
        summary.entries.toList();
    sortedSummary.sort((a, b) => a.key.compareTo(b.key));

    for (var entry in sortedSummary) {
      final totalMeters = entry.value.$1;
      final pieces = entry.value.$2.toList()..sort();

      final parts = entry.key.split('||');
      final material = parts[0];
      final color = parts.length > 1 ? parts[1] : '';

      finalReport.add(MaterialEstimate(
        material: material,
        color: color,
        meters: totalMeters,
        pieceNames: pieces,
      ));
    }

    if (!mounted) return;

    // 3. NAVEGA para a nova página de Relatório para VISUALIZAÇÃO
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportSummaryPage(
          ticketIds: ticketIds,
          estimates: finalReport,
        ),
      ),
    );

    // 4. Limpa a seleção e o loading
    setState(() {
      _isLoading = false;
      _selectedIds.clear();
    });
  }
  // --- FIM DA FUNÇÃO DE NAVEGAÇÃO ---

  @override
  Widget build(BuildContext context) {
    final bool isSelecting = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelecting
            ? '${_selectedIds.length} selecionadas'
            : 'Fichas Salvas'),

        // --- APPBAR ACTIONS ATUALIZADA (SÓ RELATÓRIO E LIMPAR) ---
        actions: [
          if (isSelecting) ...[
            // 1. BOTÃO DE VISUALIZAR RELATÓRIO (A ÚNICA OPÇÃO NA APPBAR)
            IconButton(
              icon: const Icon(Icons.list_alt), // Ícone de relatório/lista
              tooltip: 'Ver Relatório de Consumo',
              onPressed: _isLoading
                  ? null
                  : _onGenerateAndNavigateToReport, // CORREÇÃO DE FLUXO
            ),

            // 2. Botão de Limpar
            IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Limpar seleção',
                onPressed: () {
                  setState(() => _selectedIds.clear());
                }),
            // O BOTÃO DE PDF FOI MOVIDO PARA O FAB
          ]
        ],
        // --- FIM DA ATUALIZAÇÃO ---
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar Ficha, Modelo, Cor, Cliente...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box>(
              valueListenable: HiveService.listenable()!,
              builder: (context, box, _) {
                _allTickets = HiveService.getAllTickets();

                final List<Ticket> filteredTickets;
                if (_searchQuery.isEmpty) {
                  filteredTickets = _allTickets;
                } else {
                  filteredTickets = _allTickets.where((ticket) {
                    final ticketId = ticket.id.toLowerCase();
                    final modelo = ticket.modelo.toLowerCase();
                    final cor = ticket.cor.toLowerCase();
                    final cliente = ticket.cliente.toLowerCase();

                    return ticketId.contains(_searchQuery) ||
                        modelo.contains(_searchQuery) ||
                        cor.contains(_searchQuery) ||
                        cliente.contains(_searchQuery);
                  }).toList();
                }

                if (filteredTickets.isEmpty) {
                  return Center(
                      child: Text(_allTickets.isEmpty
                          ? 'Nenhuma ficha salva.'
                          : 'Nenhuma ficha encontrada para "$_searchQuery".'));
                }

                return ListView.separated(
                  itemCount: filteredTickets.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final t = filteredTickets[i];
                    final isSelected = _selectedIds.contains(t.id);

                    return ListTile(
                      tileColor: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : null,
                      leading: isSelected
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).primaryColor)
                          : const Icon(Icons.receipt_long_outlined),
                      title: Text('Ficha ${t.id} • ${t.modelo} ${t.cor}'),
                      subtitle: Text('Marca: ${t.marca} • Pares: ${t.pairs}'),
                      onLongPress: () {
                        _toggleSelection(t.id);
                      },
                      onTap: () {
                        if (isSelecting) {
                          _toggleSelection(t.id);
                        } else {
                          _navigateToDetails(t);
                        }
                      },
                      trailing: isSelecting
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () {
                                _confirmDelete(context, t);
                              },
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // --- FAB (Floating Action Button): SÓ PDF ---
      floatingActionButton: isSelecting
          ? FloatingActionButton.extended(
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text('Gerar PDF (${_selectedIds.length})'),
              onPressed: _isLoading ? null : _generateBatchPdf,
            )
          : null,
      // --- FIM DO FAB ---
    );
  }

  void _confirmDelete(BuildContext context, Ticket ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Ficha?'),
        content: Text(
            'Tem certeza que deseja excluir a ficha ${ticket.id} (${ticket.modelo})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              HiveService.deleteById(ticket.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Ficha ${ticket.id} excluída com sucesso.')),
              );
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
