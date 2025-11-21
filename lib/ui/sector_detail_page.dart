import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fl_chart/fl_chart.dart'; // <-- ESTA LINHA DEVE ESTAR PRESENTE
import 'package:gestor_calcados_new/models/sector_models.dart';
import 'package:gestor_calcados_new/services/production_manager.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';

class SectorDetailPage extends StatefulWidget {
  final ConfigurableSector sectorModel;
  final AppUserModel user;

  const SectorDetailPage(
      {super.key, required this.sectorModel, required this.user});

  @override
  State<SectorDetailPage> createState() => _SectorDetailPageState();
}

class _SectorDetailPageState extends State<SectorDetailPage> {
  late ConfigurableSector _data;

  final Map<String, DateTime> _lastSeen = {};
  final Map<String, Set<String>> _processedActions = {};
  static const int _ignoreWindowMs = 800;
  bool _scanning = false;

  // --- GETTERS LIMPOS E CORRIGIDOS ---
  // Acessores para buscar dados de produção (assíncronos)
  Future<int> get _emProducao => ProductionManager.instance
      .getFichasEmProducao(_data.firestoreId, widget.user.teamId);

  Future<int> get _producaoDia => ProductionManager.instance.getDailyProduction(
      _data.firestoreId, DateTime.now(), widget.user.teamId);

  Future<Map<String, int>> get _historico7Dias => ProductionManager.instance
      .getSevenDayProductionHistory(_data.firestoreId, widget.user.teamId);
  // --- FIM DOS GETTERS ---

  @override
  void initState() {
    super.initState();
    _data = widget.sectorModel;
  }

  String get _agoraFull =>
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  // ===================================================================
  // === FUNÇÃO _openScanner (inalterada na lógica, mas limpa) ===
  // ===================================================================
  Future<void> _openScanner({required bool entrada}) async {
    if (_scanning) return;
    _scanning = true;
    bool fired = false;

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    final _manualInputController = TextEditingController();

    try {
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final actionString = entrada ? 'entrada' : 'saida';

          Future<void> _processDetected(String bc) async {
            final now = DateTime.now();
            final last = _lastSeen[bc];
            if (last != null &&
                now.difference(last).inMilliseconds < _ignoreWindowMs) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).removeCurrentSnackBar();
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Leitura duplicada detectada.'),
                      duration: Duration(milliseconds: 900)),
                );
              }
              return;
            }
            _lastSeen[bc] = now;

            final actions = _processedActions[bc];
            if (actions != null && actions.contains(actionString)) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).removeCurrentSnackBar();
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Este QR já teve "$actionString" registrado anteriormente.'),
                      duration: const Duration(seconds: 2)),
                );
              }
              return;
            }

            fired = true;
            try {
              await controller.stop();
            } catch (_) {}
            if (ctx.mounted) Navigator.pop(ctx, bc);
          }

          Future<void> _processManualInput() async {
            final text = _manualInputController.text.trim();
            if (text.isEmpty || fired) return;

            fired = true;
            try {
              await controller.stop();
            } catch (_) {}
            if (ctx.mounted) Navigator.pop(ctx, text);
          }

          return StatefulBuilder(builder: (ctx, setModal) {
            return Padding(
              padding: MediaQuery.of(ctx).viewInsets,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12))),
                    const SizedBox(height: 12),
                    Text(entrada ? 'Dar ENTRADA' : 'Dar SAÍDA',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualInputController,
                              decoration: const InputDecoration(
                                labelText: 'Digitar ID da Ficha (ex: 2025-002)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: (value) async =>
                                  await _processManualInput(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.send),
                            onPressed: _processManualInput,
                            tooltip: 'Confirmar',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MobileScanner(
                                controller: controller,
                                fit: BoxFit.cover,
                                onDetect: (capture) async {
                                  if (fired) return;
                                  final bc = capture.barcodes.isNotEmpty
                                      ? (capture.barcodes.first.rawValue ??
                                          capture.barcodes.first.displayValue)
                                      : null;
                                  if (bc == null) return;
                                  await _processDetected(bc);
                                },
                              ),
                              Center(
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.9),
                                        width: 2),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 10),
                                  decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                      'Aponte o QR ao centro ou digite o ID acima',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                        tooltip: 'Lanterna',
                        onPressed: () async {
                          try {
                            await controller.toggleTorch();
                          } catch (e) {
                            if (ctx.mounted)
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('Falha na lanterna: $e'),
                                  behavior: SnackBarBehavior.floating));
                          }
                        },
                        icon: const Icon(Icons.flash_on),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Trocar câmera',
                        onPressed: () async {
                          try {
                            await controller.switchCamera();
                          } catch (e) {
                            if (ctx.mounted)
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('Falha ao trocar câmera: $e'),
                                  behavior: SnackBarBehavior.floating));
                          }
                        },
                        icon: const Icon(Icons.cameraswitch),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          });
        },
      );

      _manualInputController.dispose();

      try {
        await controller.stop();
      } catch (_) {}
      try {
        controller.dispose();
      } catch (_) {}

      if (!mounted || code == null) {
        _scanning = false;
        return;
      }

      Map<String, dynamic>? ticketData;

      ticketData = ProductionManager.instance.parseQrCode(code);

      if (ticketData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('QR inválido. Tentando buscar ficha por ID...'),
            behavior: SnackBarBehavior.floating,
          ));
        }

        ticketData =
            await ProductionManager.instance.getTicketDataFromFirebase(code);

        if (ticketData == null) {
          _scanning = false;
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ficha não encontrada. Verifique o ID.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating));
          }
          return;
        }
      }

      bool success = false;
      String? errorMessage;

      try {
        if (entrada) {
          success = await ProductionManager.instance.entrada(
              ticketData: ticketData,
              sectorId: _data.firestoreId,
              teamId: widget.user.teamId);
        } else {
          success = await ProductionManager.instance.saida(
              ticketData: ticketData,
              sectorId: _data.firestoreId,
              teamId: widget.user.teamId);
        }
      } catch (e) {
        success = false;
        errorMessage = e.toString();
      }

      if (!mounted) {
        _scanning = false;
        return;
      }

      ScaffoldMessenger.of(context).removeCurrentSnackBar();

      if (success) {
        _processedActions
            .putIfAbsent(code, () => <String>{})
            .add(entrada ? 'entrada' : 'saida');
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(entrada
                  ? 'Entrada registrada! (Ficha: ${ticketData['id']})'
                  : 'Saída registrada! (Ficha: ${ticketData['id']})'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage ??
                  'Não foi possível registrar ${entrada ? 'entrada' : 'saída'}.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      try {
        controller.dispose();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha ao abrir o scanner: $e'),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      _scanning = false;
    }
  }

  // ===================================================================
  // === FUNÇÃO _openGargaloDialog (inalterada na lógica, mas limpa) ===
  // ===================================================================
  Future<void> _openGargaloDialog() async {
    final pm = ProductionManager.instance;
    String? selectedReason;
    String customReason = '';
    String partName = '';

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final bool showPartField = selectedReason == kMissingPartReason;
            final bool showCustomField = selectedReason == kOtherReason;

            return AlertDialog(
              title: const Text('Registrar gargalo'),
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
                        setDialogState(() {
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
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (value) => customReason = value.trim(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Registrar')),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (ok == true) {
      if (selectedReason == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Você deve selecionar um motivo.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
        return;
      }

      try {
        await pm.createBottleneck(
          sectorId: _data.firestoreId,
          reason: selectedReason!,
          teamId: widget.user.teamId,
          customReason: customReason.isNotEmpty ? customReason : null,
          partName: partName.isNotEmpty ? partName : null,
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Gargalo registrado e notificação enviada!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao registrar gargalo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  // ===================================================================
  // === MÉTODO BUILD ATUALIZADO (Inclui Histórico) ===
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Setor: ${_data.label}')),
      // FutureBuilder AGORA CARREGA OS 3 FUTURES
      body: FutureBuilder<List<dynamic>>(
        // Incluindo o _historico7Dias no Future.wait
        future: Future.wait([_producaoDia, _emProducao, _historico7Dias]),
        builder: (context, snapshot) {
          int producaoDia = 0;
          int emProducao = 0;
          Map<String, int> historico = {};

          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            // Desempacotando os resultados com cast explícito
            producaoDia = snapshot.data![0] as int;
            emProducao = snapshot.data![1] as int;
            historico = snapshot.data![2] as Map<String, int>;
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                elevation: 2,
                child: ListTile(
                  title: const Text('Produção do dia (pares)'),
                  subtitle:
                      (snapshot.connectionState == ConnectionState.waiting)
                          ? const Text('Calculando...',
                              style: TextStyle(fontSize: 22))
                          : Text('$producaoDia',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                  trailing: Text(_agoraFull),
                ),
              ),

              const SizedBox(height: 12),
              // CARD DO MINI-GRÁFICO
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Histórico de 7 Dias (Pares)',
                          style: tema.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: LinearProgressIndicator())
                      else if (historico.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (historico.values
                                            .reduce((a, b) => a > b ? a : b) *
                                        1.2)
                                    .toDouble(),
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final keys = historico.keys.toList();
                                        if (value.toInt() >= 0 &&
                                            value.toInt() < keys.length) {
                                          final date = DateTime.parse(
                                              keys[value.toInt()]);
                                          return Text(
                                            DateFormat('dd/MM').format(date),
                                            style:
                                                const TextStyle(fontSize: 10),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true, reservedSize: 40),
                                  ),
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: historico.entries
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.value.toDouble(),
                                        color: tema.colorScheme.primary,
                                        width: 16,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                              'Nenhum dado de produção encontrado nos últimos 7 dias.'),
                        ),
                    ],
                  ),
                ),
              ),
              // FIM DO CARD DO MINI-GRÁFICO

              const SizedBox(height: 12),
              Text('Ações', style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(
                    onPressed: () => _openScanner(entrada: true),
                    icon: const Icon(Icons.login),
                    label: const Text('Dar entrada')),
                ElevatedButton.icon(
                    onPressed: () => _openScanner(entrada: false),
                    icon: const Icon(Icons.logout),
                    label: const Text('Dar saída')),
                OutlinedButton.icon(
                    onPressed: _openGargaloDialog,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Gargalo')),
              ]),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Status do setor'),
                  subtitle: (snapshot.connectionState ==
                          ConnectionState.waiting)
                      ? const Text('Calculando...')
                      : Text(
                          'Em produção: $emProducao  •  Atualizado: ${DateFormat('HH:mm').format(DateTime.now())}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
