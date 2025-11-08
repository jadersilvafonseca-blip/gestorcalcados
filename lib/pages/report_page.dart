import 'package:flutter/material.dart';
import '../models/sector_models.dart'; // Importa seus setores
import '../services/production_manager.dart'; // Importa o manager e os modelos de relatório

// Enum para controlar o tipo de relatório
enum ReportType { production, bottleneck }

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedSectors = {};
  bool _selectAllSectors = false;
  bool _isLoading = false;

  // --- ATUALIZADO: Estado para tipo de relatório e resultados ---
  ReportType _selectedReportType = ReportType.production;
  ProductionReport? _productionReport;
  BottleneckReport? _bottleneckReport;
  // -----------------------------------------------------------

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

  // --- NOVO: Formata Duração (ex: 2h 15m) ---
  String _formatDuration(Duration duration) {
    if (duration.inMinutes == 0) return '0m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String result = '';
    if (hours > 0) {
      result += '${hours}h ';
    }
    if (minutes > 0 || hours == 0) {
      result += '${minutes}m';
    }
    return result.trim();
  }
  // ---------------------------------------------

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

  /// ATUALIZADO: Gera o relatório correto baseado no tipo
  void _generateReport() {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um período.')),
      );
      return;
    }

    // Validação específica para relatório de produção
    if (_selectedReportType == ReportType.production &&
        _selectedSectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione pelo menos um setor.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _productionReport = null; // Limpa relatórios antigos
      _bottleneckReport = null; // Limpa relatórios antigos
    });

    // Simula um delay para o usuário ver o loading
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_selectedReportType == ReportType.production) {
        // --- Gera Relatório de PRODUÇÃO ---
        final sectorNames = {
          for (var s in Sector.values) s.firestoreId: s.label
        };
        final report = ProductionManager.instance.generateProductionReport(
          startDate: _selectedDateRange!.start,
          endDate: _selectedDateRange!.end,
          sectorIds: _selectedSectors.toList(),
          sectorNames: sectorNames,
        );
        setState(() {
          _productionReport = report;
          _isLoading = false;
        });
      } else {
        // --- Gera Relatório de GARGALOS ---
        final report = ProductionManager.instance.generateBottleneckReport(
          startDate: _selectedDateRange!.start,
          endDate: _selectedDateRange!.end,
        );
        setState(() {
          _bottleneckReport = report;
          _isLoading = false;
        });
      }
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
          // --- ATUALIZADO: Decide qual relatório mostrar ---
          else if (_productionReport != null)
            _buildProductionReportDisplay(_productionReport!)
          else if (_bottleneckReport != null)
            _buildBottleneckReportDisplay(_bottleneckReport!)
          // -----------------------------------------------
          else
            Center(
              child: Text(
                'Selecione o período${_selectedReportType == ReportType.production ? ' e os setores' : ''} para gerar um relatório.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
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
            // --- NOVO: Seletor de Tipo de Relatório ---
            Text('Tipo de Relatório',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ReportType>(
                segments: const [
                  ButtonSegment(
                      value: ReportType.production,
                      label: Text('Produção'),
                      icon: Icon(Icons.inventory_2_outlined)),
                  ButtonSegment(
                      value: ReportType.bottleneck,
                      label: Text('Gargalos'),
                      icon: Icon(Icons.warning_amber_rounded)),
                ],
                selected: {_selectedReportType},
                onSelectionChanged: (Set<ReportType> newSelection) {
                  setState(() {
                    _selectedReportType = newSelection.first;
                    // Limpa resultados antigos ao trocar de tipo
                    _productionReport = null;
                    _bottleneckReport = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // ------------------------------------------

            // --- Seletor de Data ---
            Text('Período', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(rangeText),
              onTap: _pickDateRange,
            ),

            // --- ATUALIZADO: Seletor de Setores (só aparece para produção) ---
            if (_selectedReportType == ReportType.production) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Setores',
                      style: Theme.of(context).textTheme.titleMedium),
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
            ],
            // --- FIM DA ATUALIZAÇÃO ---

            const SizedBox(height: 16),
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

  /// Widget que exibe o relatório de PRODUÇÃO gerado
  Widget _buildProductionReportDisplay(ProductionReport report) {
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
                  'Resumo de Produção',
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

  // --- NOVO: Widget que exibe o relatório de GARGALOS ---
  Widget _buildBottleneckReportDisplay(BottleneckReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Resumo Geral de Gargalos ---
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo de Gargalos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Período: ${_formatDate(report.startDate)} a ${_formatDate(report.endDate)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total de Ocorrências:',
                  '${report.summary.fold<int>(0, (prev, item) => prev + item.count)}',
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Tempo Total Perdido:',
                  _formatDuration(report.summary.fold<Duration>(Duration.zero,
                      (prev, item) => prev + item.totalDuration)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Detalhes por Motivo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Divider(),

        // --- Detalhes por Motivo ---
        if (report.summary.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
                child: Text('Nenhum gargalo resolvido neste período.',
                    style: TextStyle(color: Colors.grey))),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: report.summary.length,
          itemBuilder: (context, index) {
            final item = report.summary[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.red.shade800),
                title: Text(item.reason,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${item.count} ${item.count > 1 ? 'ocorrências' : 'ocorrência'}'),
                trailing: Text(
                  _formatDuration(item.totalDuration),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  // --- FIM DO NOVO WIDGET ---

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
