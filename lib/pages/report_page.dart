// lib/pages/report_page.dart
import 'package:flutter/material.dart';
import '../models/sector_models.dart'; // Importa seus setores
import '../services/production_manager.dart'; // Importa o manager e os modelos de relatório

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTimeRange? _selectedDateRange;
  // Set armazena os setores selecionados (usando o ID)
  final Set<String> _selectedSectors = {};
  bool _selectAllSectors = false;

  ProductionReport? _report;
  bool _isLoading = false;

  // Formata a data para exibição (ex: 31/10/2025)
  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // Formata a data e hora (ex: 31/10 14:30)
  String _formatDateTime(String? isoDate) {
    if (isoDate == null) return '??';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Data inválida';
    }
  }

  /// Mostra o seletor de data
  void _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, now.month, now.day);
    final lastDate = now;

    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: now,
      initialDateRange: _selectedDateRange,
    );

    if (range != null) {
      setState(() {
        _selectedDateRange = range;
      });
    }
  }

  /// Gera o relatório
  void _generateReport() {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um período.')),
      );
      return;
    }
    if (_selectedSectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione pelo menos um setor.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Mapeia os IDs dos setores para os nomes (para o relatório)
    final sectorNames = {for (var s in Sector.values) s.firestoreId: s.label};

    // Chama a nova função no ProductionManager
    final report = ProductionManager.instance.generateProductionReport(
      startDate: _selectedDateRange!.start,
      endDate: _selectedDateRange!.end,
      sectorIds: _selectedSectors.toList(),
      sectorNames: sectorNames,
    );

    // Simula um pequeno delay para o usuário ver o loading
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _report = report;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerar Relatório'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildParamsCard(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_report != null)
            _buildReportDisplay(_report!)
          else
            const Center(
              child: Text(
                'Selecione o período e os setores para gerar um relatório.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  /// Card com os parâmetros de seleção
  Widget _buildParamsCard() {
    final rangeText = _selectedDateRange == null
        ? 'Clique para selecionar'
        : '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Seletor de Data ---
            Text('Período', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(rangeText),
              onTap: _pickDateRange,
            ),
            const Divider(),

            // --- Seletor de Setores ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Setores', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  child: Text(_selectAllSectors ? 'Limpar' : 'Todos'),
                  onPressed: () {
                    setState(() {
                      _selectAllSectors = !_selectAllSectors;
                      _selectedSectors.clear();
                      if (_selectAllSectors) {
                        _selectedSectors
                            .addAll(Sector.values.map((s) => s.firestoreId));
                      }
                    });
                  },
                ),
              ],
            ),
            // Chips para cada setor
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: Sector.values.map((sector) {
                final isSelected =
                    _selectedSectors.contains(sector.firestoreId);
                return ChoiceChip(
                  label: Text(sector.label),
                  selectedColor:
                      Theme.of(context).primaryColor.withOpacity(0.2),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSectors.add(sector.firestoreId);
                      } else {
                        _selectedSectors.remove(sector.firestoreId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // --- Botão Gerar ---
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.assessment),
                label: const Text('Gerar Relatório'),
                onPressed: _generateReport,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget que exibe o relatório gerado
  Widget _buildReportDisplay(ProductionReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Resumo Geral ---
        Card(
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo Geral do Período',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColorDark,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Período: ${_formatDate(report.startDate)} a ${_formatDate(report.endDate)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total Produzido no Período:',
                  '${report.totalProducedInRange} pares',
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Total Em Produção (Agora):',
                  '${report.totalCurrentlyInProduction} pares',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Detalhes por Setor',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Divider(),

        // --- Detalhes por Setor ---
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: report.sectorData.length,
          itemBuilder: (context, index) {
            final data = report.sectorData[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  data.sectorName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Produzido no período
                  Text(
                    'Produzido no Período: ${data.producedInRange} pares',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (data.finalizedFichasInRange.isEmpty)
                    const Text('Nenhuma ficha finalizada no período.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ...data.finalizedFichasInRange.map((ficha) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: Text(
                              'Ficha: ${ficha['ticketId']} (${ficha['pairs']} pares)'),
                          subtitle:
                              Text('Saída: ${_formatDateTime(ficha['outAt'])}'),
                        )),

                  const Divider(height: 24),

                  // Em produção agora
                  Text(
                    'Em Produção (Agora): ${data.currentlyInProduction} pares',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (data.openFichas.isEmpty)
                    const Text('Nenhuma ficha aberta neste setor.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ...data.openFichas.map((ficha) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.hourglass_top,
                              color: Colors.orange),
                          title: Text(
                              'Ficha: ${ficha['ticketId']} (${ficha['pairs']} pares)'),
                          subtitle: Text(
                              'Entrada: ${_formatDateTime(ficha['inAt'])}'),
                        )),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
