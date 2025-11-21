import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/report_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../services/production_manager.dart';
import '../models/sector_models.dart' hide kTransitSectorId;

// ENUMS no topo para organização
enum ReportType { production, bottleneck }

enum MovementFilterType { entradas, saidas, ambos }

// ===============================================
// CLASSES DE MODELO (DEFINIDAS AQUI PARA OS DETALHES NA TELA)
// (As classes FichaMovement, DailySectorMovements e SectorDetailedReport
// foram mantidas aqui, pois são estruturas internas da tela para organização
// da visualização do relatório detalhado)
// ===============================================

/// Representa uma única movimentação de ficha
class FichaMovement {
  final String fichaId;
  final int pairs;
  final DateTime timestamp;

  FichaMovement(
      {required this.fichaId, required this.pairs, required this.timestamp});
}

/// Agrupa as movimentações de um dia para um setor
class DailySectorMovements {
  final List<FichaMovement> entradas = [];
  final List<FichaMovement> saidas = [];
}

/// Relatório detalhado completo para um único setor
class SectorDetailedReport {
  final String sectorId;
  final String sectorName;
  // Mapa de [Dia Normalizado] -> Movimentações
  final Map<DateTime, DailySectorMovements> dailyMovements = {};
  int totalEntradas = 0;
  int totalSaidas = 0;

  SectorDetailedReport({required this.sectorId, required this.sectorName});

  /// Adiciona uma movimentação a este relatório de setor
  void addMovement({
    required String fichaId,
    required int pairs,
    required DateTime timestamp,
    required String type, // 'entrada' or 'saida'
  }) {
    // Normaliza o dia (remove horas/minutos)
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    // Pega ou cria o registro para aquele dia
    final dailyData =
        dailyMovements.putIfAbsent(day, () => DailySectorMovements());

    final movement =
        FichaMovement(fichaId: fichaId, pairs: pairs, timestamp: timestamp);

    if (type == 'entrada') {
      dailyData.entradas.add(movement);
      totalEntradas += pairs;
    } else if (type == 'saida') {
      dailyData.saidas.add(movement);
      totalSaidas += pairs;
    }
  }
}
// ===============================================
// FIM DAS CLASSES DE MODELO INTERNAS
// ===============================================

class ReportPage extends StatefulWidget {
  final AppUserModel user;
  const ReportPage({super.key, required this.user});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedSectors = {};
  bool _selectAllSectors = false;
  bool _isLoading = false;

  ReportType _selectedReportType = ReportType.production;
  MovementFilterType _selectedMovementFilter = MovementFilterType.saidas;

  // Relatórios de resumo
  ProductionReport? _productionReport;
  BottleneckReport? _bottleneckReport;

  // Armazena os dados detalhados para a UI e PDF
  Map<String, SectorDetailedReport> _detailedReportData = {};

  List<ConfigurableSector> _sectors = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now.add(const Duration(days: 1)),
    );
    _loadSectors();
  }

  Future<void> _loadSectors() async {
    if (widget.user.teamId.isEmpty) {
      _showSnack("Erro: Usuário ou Time não identificado.");
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    _sectors =
        await ProductionManager.instance.getAllSectorModels(widget.user.teamId);

    if (_sectors.isNotEmpty) {
      _selectedSectors.addAll(_sectors.map((s) => s.firestoreId));
      _selectAllSectors = true;
    }

    setState(() => _isLoading = false);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatDuration(Duration duration) {
    if (duration.inMinutes == 0) return '0m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours > 0 ? '${hours}h ' : ''}${minutes}m';
  }

  String _getMovementFilterText() {
    switch (_selectedMovementFilter) {
      case MovementFilterType.entradas:
        return 'entradas';
      case MovementFilterType.saidas:
        return 'saídas (baixas)';
      case MovementFilterType.ambos:
        return 'entradas e saídas';
    }
  }

  void _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      locale: const Locale('pt', 'BR'),
    );
    if (range != null) {
      final adjustedEnd =
          DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      setState(() => _selectedDateRange =
          DateTimeRange(start: range.start, end: adjustedEnd));
    }
  }

  void _generateReport() async {
    final teamId = widget.user.teamId;
    if (teamId.isEmpty) {
      _showSnack("ERRO: Não foi possível identificar seu time. Tente relogar.");
      return;
    }

    if (_selectedDateRange == null) {
      _showSnack('Por favor, selecione um período.');
      return;
    }

    if (_selectedReportType == ReportType.production &&
        _selectedSectors.isEmpty) {
      _showSnack('Por favor, selecione pelo menos um setor.');
      return;
    }

    setState(() {
      _isLoading = true;
      _productionReport = null;
      _bottleneckReport = null;
      _detailedReportData = {}; // Limpa o detalhamento anterior
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final sectorNames = {
      for (var s in _sectors) s.firestoreId: s.label,
    };

    if (_selectedReportType == ReportType.production) {
      try {
        // 1. GERAR RELATÓRIO DE RESUMO (USA FILTRO NO SERVER: outAt)
        final report =
            await ProductionManager.instance.generateProductionReport(
          startDate: _selectedDateRange!.start,
          endDate: _selectedDateRange!.end,
          sectorIds: _selectedSectors.toList(),
          sectorNames: sectorNames,
          teamId: teamId,
        );
        _productionReport = report;

        // 2. BUSCAR DADOS DETALHADOS PARA A TELA E PDF
        await _generateDetailedData(
          teamId,
          sectorNames,
          _selectedDateRange!.start,
          _selectedDateRange!.end,
        );
      } catch (e) {
        _showSnack('Erro ao gerar relatório de Produção. Verifique o console.');
        debugPrint('Erro ao gerar relatório de Produção: $e');
      }
    } else {
      // RELATÓRIO DE GARGALOS
      try {
        final report =
            await ProductionManager.instance.generateBottleneckReport(
          startDate: _selectedDateRange!.start,
          endDate: _selectedDateRange!.end,
          sectorNames: sectorNames,
          teamId: teamId,
        );
        _bottleneckReport = report;
      } catch (e) {
        _showSnack('Erro ao gerar relatório de Gargalos. Verifique o console.');
        debugPrint('Erro ao gerar relatório de Gargalos: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  // =======================================================================
  // NOVA LÓGICA: Busca dados detalhados para preencher o _detailedReportData
  // =======================================================================
  Future<void> _generateDetailedData(
    String teamId,
    Map<String, String> sectorNames,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, SectorDetailedReport> detailedData = {};
    final endDateAdjusted =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final startNormalized =
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);

    for (var sectorId in _selectedSectors) {
      detailedData[sectorId] = SectorDetailedReport(
        sectorId: sectorId,
        sectorName: sectorNames[sectorId] ?? sectorId,
      );
    }

    // Determine quais campos de data consultar (inAt, outAt ou ambos)
    final List<String> dateFieldsToFetch = [];
    if (_selectedMovementFilter == MovementFilterType.entradas ||
        _selectedMovementFilter == MovementFilterType.ambos) {
      dateFieldsToFetch.add('inAt');
    }
    if (_selectedMovementFilter == MovementFilterType.saidas ||
        _selectedMovementFilter == MovementFilterType.ambos) {
      dateFieldsToFetch.add('outAt');
    }

    // Busque e processe os movimentos
    for (final dateField in dateFieldsToFetch) {
      final movements =
          await ProductionManager.instance.getDetailedMovementsForReport(
        teamId: teamId,
        sectorIds: _selectedSectors.toList(),
        startDate: startNormalized,
        endDateAdjusted: endDateAdjusted,
        dateField: dateField,
      );

      // Processamento e agrupamento no cliente (o volume é menor após o filtro de data)
      for (var data in movements) {
        final docSectorId = data['sector'] as String?;
        final pairs = (data['pairs'] as num?)?.toInt() ?? 0;
        final ticketId = data['ticketId'] as String? ?? '';

        if (docSectorId == null ||
            !_selectedSectors.contains(docSectorId) ||
            pairs <= 0) {
          continue;
        }

        final timestamp = (data[dateField] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        final type = dateField == 'inAt' ? 'entrada' : 'saida';

        // Usa a lógica de agregação do modelo interno (SectorDetailedReport)
        detailedData[docSectorId]!.addMovement(
          fichaId: ticketId,
          pairs: pairs,
          timestamp: timestamp,
          type: type,
        );
      }
    }

    setState(() {
      _detailedReportData = detailedData;
    });
  }

  // -----------------------------------------------------------------------
  // O restante do ReportPage (PDF e Widgets de UI) é mantido.
  // -----------------------------------------------------------------------

  // === GERAR PDF ===
  Future<void> _generatePdf() async {
    // ... (Lógica do PDF mantida, usando _productionReport e _detailedReportData) ...
    // A lógica interna do PDF que usa _detailedReportData não mudou e pode ser mantida.
    // ... (restante do código do PDF)
    if (_productionReport == null && _bottleneckReport == null) {
      _showSnack('Nenhum relatório para exportar.');
      return;
    }

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final filterText = _getMovementFilterText();

    if (_productionReport != null) {
      // PDF de Produção
      final report = _productionReport!;
      final detailedData = _detailedReportData;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RELATÓRIO DE PRODUÇÃO',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Baseado nas $filterText dos setores no período', // Subtítulo dinâmico
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Período:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        '${_formatDate(report.startDate)} até ${_formatDate(report.endDate)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Gerado em:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(dateFormatter.format(now)),
                  ],
                ),
                pw.SizedBox(height: 16),
              ]),
          build: (context) {
            return [
              // 1. Bloco de Total
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL DE PARES PROCESSADOS',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${report.totalProducedInRange}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // 2. Bloco de Totais por Setor
              pw.Text(
                'TOTAIS POR SETOR (BASEADO NO FILTRO)',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Setor',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Pares Processados',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...report.sectorData.map((data) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(data.sectorName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${data.producedInRange} pares'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),

              // =============================================
              // 3. Bloco de Detalhamento por Ficha
              // =============================================
              pw.Text(
                'DETALHAMENTO DIA A DIA POR SETOR',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),

              if (detailedData.isEmpty)
                pw.Text(
                    'Nenhuma movimentação encontrada para os filtros selecionados.',
                    style: const pw.TextStyle(color: PdfColors.grey700))
              else
                // Itera sobre cada SETOR
                ...detailedData.values.map((sectorReport) {
                  // Ordena os dias para este setor
                  final sortedDays = sectorReport.dailyMovements.keys.toList()
                    ..sort();

                  // Se o setor não tiver movimentos (baseado no filtro), pode pular
                  if (sortedDays.isEmpty) return pw.Container();

                  return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 16),
                        pw.Text(
                          'Setor: ${sectorReport.sectorName}',
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey800),
                        ),
                        pw.SizedBox(height: 8),

                        // Itera sobre cada DIA deste setor
                        ...sortedDays.map((day) {
                          final dayData = sectorReport.dailyMovements[day]!;
                          bool showEntradas = filterText != 'saídas (baixas)' &&
                              dayData.entradas.isNotEmpty;
                          bool showSaidas = filterText != 'entradas' &&
                              dayData.saidas.isNotEmpty;

                          // Se não houver nada para mostrar neste dia, pula
                          if (!showEntradas && !showSaidas)
                            return pw.Container();

                          return pw.Container(
                              padding:
                                  const pw.EdgeInsets.only(left: 8, bottom: 8),
                              child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'Dia: ${_formatDate(day)}',
                                      style: pw.TextStyle(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    // Tabela com Entradas e Saídas
                                    pw.Table(
                                        border: pw.TableBorder.all(
                                            color: PdfColors.grey400),
                                        children: [
                                          // Cabeçalho
                                          pw.TableRow(
                                              decoration:
                                                  const pw.BoxDecoration(
                                                      color: PdfColors.grey200),
                                              children: [
                                                if (filterText !=
                                                    'saídas (baixas)')
                                                  pw.Padding(
                                                      padding: const pw
                                                          .EdgeInsets.all(5),
                                                      child: pw.Text(
                                                          'Entradas (Ficha | Pares)',
                                                          style: pw.TextStyle(
                                                              fontWeight: pw
                                                                  .FontWeight
                                                                  .bold))),
                                                if (filterText != 'entradas')
                                                  pw.Padding(
                                                      padding: const pw
                                                          .EdgeInsets.all(5),
                                                      child: pw.Text(
                                                          'Saídas (Ficha | Pares)',
                                                          style: pw.TextStyle(
                                                              fontWeight: pw
                                                                  .FontWeight
                                                                  .bold))),
                                              ]),
                                          // Linha de dados
                                          pw.TableRow(
                                              verticalAlignment: pw
                                                  .TableCellVerticalAlignment
                                                  .top,
                                              children: [
                                                // Coluna de Entradas
                                                if (filterText !=
                                                    'saídas (baixas)')
                                                  pw.Padding(
                                                      padding:
                                                          const pw.EdgeInsets.all(
                                                              5),
                                                      child: pw.Column(
                                                          crossAxisAlignment: pw
                                                              .CrossAxisAlignment
                                                              .start,
                                                          children: dayData
                                                              .entradas
                                                              .map((mov) => pw.Text(
                                                                  '${mov.fichaId}: ${mov.pairs} pares'))
                                                              .toList())),

                                                // Coluna de Saídas
                                                if (filterText != 'entradas')
                                                  pw.Padding(
                                                      padding:
                                                          const pw
                                                              .EdgeInsets.all(
                                                              5),
                                                      child: pw.Column(
                                                          crossAxisAlignment: pw
                                                              .CrossAxisAlignment
                                                              .start,
                                                          children: dayData
                                                              .saidas
                                                              .map((mov) => pw.Text(
                                                                  '${mov.fichaId}: ${mov.pairs} pares'))
                                                              .toList())),
                                              ])
                                        ])
                                  ]));
                        })
                      ]);
                }),
            ];
          },
        ),
      );
    } else if (_bottleneckReport != null) {
      // PDF de Gargalos (Sem alterações)
      final report = _bottleneckReport!;
      final totalOccurrences =
          report.summary.fold(0, (sum, item) => sum + item.count);
      final totalDowntime = report.summary
          .fold(Duration.zero, (sum, item) => sum + item.totalDuration);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RELATÓRIO DE GARGALOS',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Período:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        '${_formatDate(report.startDate)} até ${_formatDate(report.endDate)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Gerado em:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(dateFormatter.format(now)),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total de Ocorrências:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('$totalOccurrences',
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tempo Total Parado:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(_formatDuration(totalDowntime),
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  'DETALHAMENTO',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Motivo',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Ocorrências',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Tempo Total',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...report.summary.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.reason),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item.count}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatDuration(item.totalDuration)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // Mostrar preview e opções de impressão/salvar
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'relatorio_${_selectedReportType == ReportType.production ? 'producao' : 'gargalos'}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf',
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerar Relatório'),
        actions: [
          if (_productionReport != null || _bottleneckReport != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Exportar PDF',
              onPressed: _generatePdf,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildParamsCard(),
                const SizedBox(height: 16),

                // Card de Resumo
                if (_productionReport != null)
                  _buildProductionReportDisplay(_productionReport!)
                // Card de Detalhes
                else if (_bottleneckReport != null)
                  _buildBottleneckReportDisplay(_bottleneckReport!),

                // Renderiza o relatório detalhado SE houver dados
                if (_detailedReportData.isNotEmpty)
                  _buildDetailedProductionReport(),

                // Mensagem de "Selecione..."
                if (_productionReport == null && _bottleneckReport == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Selecione o período${_selectedReportType == ReportType.production ? ' e os setores' : ''} para gerar um relatório.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton:
          (_productionReport != null || _bottleneckReport != null)
              ? FloatingActionButton.extended(
                  onPressed: _generatePdf,
                  icon: const Icon(Icons.print),
                  label: const Text('Gerar PDF'),
                )
              : null,
    );
  }

  Widget _buildParamsCard() {
    final rangeText = _selectedDateRange == null
        ? 'Clique para selecionar'
        : '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tipo de Relatório',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ReportType>(
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
            onSelectionChanged: (Set<ReportType> sel) {
              setState(() {
                _selectedReportType = sel.first;
                _productionReport = null;
                _bottleneckReport = null;
                _detailedReportData = {};
              });
            },
          ),
          const SizedBox(height: 16),
          Text('Período', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(rangeText),
            onTap: _pickDateRange,
          ),
          if (_selectedReportType == ReportType.production) ...[
            const Divider(),
            Text('Filtro de Movimentação',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<MovementFilterType>(
              segments: const [
                ButtonSegment(
                    value: MovementFilterType.entradas,
                    label: Text('Entradas'),
                    icon: Icon(Icons.input)),
                ButtonSegment(
                    value: MovementFilterType.saidas,
                    label: Text('Saídas'),
                    icon: Icon(Icons.output)),
                ButtonSegment(
                    value: MovementFilterType.ambos,
                    label: Text('Ambos'),
                    icon: Icon(Icons.sync_alt)),
              ],
              selected: {_selectedMovementFilter},
              onSelectionChanged: (Set<MovementFilterType> sel) {
                setState(() {
                  _selectedMovementFilter = sel.first;
                  _productionReport = null; // Limpa relatório ao mudar filtro
                  _detailedReportData = {};
                });
              },
            ),
            const Divider(),
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
                            .addAll(_sectors.map((s) => s.firestoreId));
                      }
                    });
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _sectors.map((s) {
                final selected = _selectedSectors.contains(s.firestoreId);
                return ChoiceChip(
                  label: Text(s.label),
                  selected: selected,
                  selectedColor:
                      Theme.of(context).primaryColor.withOpacity(0.2),
                  onSelected: (sel) {
                    setState(() {
                      sel
                          ? _selectedSectors.add(s.firestoreId)
                          : _selectedSectors.remove(s.firestoreId);
                      _selectAllSectors =
                          _selectedSectors.length == _sectors.length;
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.assessment),
              label: const Text('Gerar Relatório'),
              onPressed: _generateReport,
            ),
          ),
        ]),
      ),
    );
  }

  // Este é o CARD DE RESUMO
  Widget _buildProductionReportDisplay(ProductionReport report) {
    final totalPairs = report.totalProducedInRange;
    final pairsBySector = {
      for (var data in report.sectorData) data.sectorName: data.producedInRange
    };
    final filterText = _getMovementFilterText();

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo da Produção', // Título alterado para "Resumo"
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Baseado nas $filterText dos setores no período',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Total de Pares Processados'),
              trailing: Text('$totalPairs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      )),
            ),
            const Divider(),
            if (pairsBySector.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Nenhuma movimentação registrada para este filtro.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...pairsBySector.entries.map((entry) {
                return ListTile(
                  leading: const Icon(Icons.bar_chart, color: Colors.blue),
                  title: Text(entry.key),
                  subtitle: const Text('Total (baseado no filtro)'),
                  trailing: Text(
                    '${entry.value} pares',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ===============================================
  // WIDGET: Card de DETALHAMENTO
  // ===============================================
  Widget _buildDetailedProductionReport() {
    // Filtra setores que não tiveram movimentação para não poluir a tela
    final sectorsWithData = _detailedReportData.values.where((sector) {
      if (_selectedMovementFilter == MovementFilterType.entradas)
        return sector.totalEntradas > 0;
      if (_selectedMovementFilter == MovementFilterType.saidas)
        return sector.totalSaidas > 0;
      return sector.totalEntradas > 0 || sector.totalSaidas > 0;
    }).toList();

    if (sectorsWithData.isEmpty) {
      return Container(); // Nenhum dado detalhado para mostrar
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhamento por Setor',
                style: Theme.of(context).textTheme.headlineSmall),
            const Divider(),

            // Itera sobre cada SETOR
            ...sectorsWithData.map((sectorReport) {
              final sortedDays = sectorReport.dailyMovements.keys.toList()
                ..sort();

              return ExpansionTile(
                title: Text(
                  sectorReport.sectorName,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18),
                ),
                subtitle: Text(_getSectorSubtitle(sectorReport)),
                initiallyExpanded: true,
                children: [
                  // Itera sobre cada DIA
                  ...sortedDays.map((day) {
                    final dayData = sectorReport.dailyMovements[day]!;
                    bool showEntradas =
                        _selectedMovementFilter != MovementFilterType.saidas &&
                            dayData.entradas.isNotEmpty;
                    bool showSaidas = _selectedMovementFilter !=
                            MovementFilterType.entradas &&
                        dayData.saidas.isNotEmpty;

                    // Se não houver nada para mostrar neste dia, pula
                    if (!showEntradas && !showSaidas) return Container();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dia: ${_formatDate(day)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Coluna de Entradas
                              if (showEntradas)
                                _buildMovementColumn(
                                    context, 'Entradas', dayData.entradas),

                              // Coluna de Saídas
                              if (showSaidas)
                                _buildMovementColumn(
                                    context, 'Saídas', dayData.saidas),
                            ],
                          )
                        ],
                      ),
                    );
                  })
                ],
              );
            })
          ],
        ),
      ),
    );
  }

  // Helper para o subtítulo do ExpansionTile
  String _getSectorSubtitle(SectorDetailedReport report) {
    if (_selectedMovementFilter == MovementFilterType.entradas) {
      return '${report.totalEntradas} pares de entrada';
    }
    if (_selectedMovementFilter == MovementFilterType.saidas) {
      return '${report.totalSaidas} pares de saída';
    }
    return '${report.totalEntradas} entradas | ${report.totalSaidas} saídas';
  }

  // Helper para renderizar a coluna de Entradas/Saídas na UI
  Widget _buildMovementColumn(
      BuildContext context, String title, List<FichaMovement> movements) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: title == 'Entradas'
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
            ),
            const Divider(height: 4),
            ...movements.map((mov) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                          child: Text(mov.fichaId,
                              overflow: TextOverflow.ellipsis)),
                      Text('${mov.pairs} p.',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // Relatório de Gargalos (Sem alterações)
  Widget _buildBottleneckReportDisplay(BottleneckReport report) {
    final totalOccurrences =
        report.summary.fold(0, (sum, item) => sum + item.count);
    final totalDowntime = report.summary
        .fold(Duration.zero, (sum, item) => sum + item.totalDuration);
    final details = report.summary
        .map(
            (item) => '${item.reason} (${_formatDuration(item.totalDuration)})')
        .toList();

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relatório de Gargalos',
                style: Theme.of(context).textTheme.headlineSmall),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: const Text('Total de Ocorrências'),
              trailing: Text('$totalOccurrences',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.timer_off),
              title: const Text('Tempo Total Parado'),
              trailing: Text(_formatDuration(totalDowntime),
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(),
            ...details
                .map((detail) => ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(detail),
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }
}
