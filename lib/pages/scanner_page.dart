import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADICIONAR
import 'package:mobile_scanner/mobile_scanner.dart'
    if (dart.library.html) 'package:gestor_calcados_new/pages/scanner_page_web_stub.dart';

import 'package:gestor_calcados_new/models/app_user_model.dart';
import '../services/production_manager.dart';
import '../models/sector_models.dart';

class ScannerPage extends StatefulWidget {
  final String sectorId;
  final AppUserModel user;

  const ScannerPage({
    super.key,
    required this.sectorId,
    required this.user,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _handling = false;

  late String _sector;
  Map<String, dynamic>? _lastParsed;
  List<ConfigurableSector> _sectors = [];
  bool _isLoadingSectors = true;
  String _currentSectorLabel = '';

  late AnimationController _animController;
  double previewHeight = 300;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _sector = widget.sectorId;
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);

    if (!kIsWeb) {
      _controller = MobileScannerController();
    }

    _loadSectors();
  }

  Future<void> _loadSectors() async {
    setState(() => _isLoadingSectors = true);
    try {
      _sectors = await ProductionManager.instance
          .getAllSectorModels(widget.user.teamId);

      final found = _sectors.any((s) => s.firestoreId == _sector);
      if (!found && _sectors.isNotEmpty) {
        _sector = _sectors.first.firestoreId;
      }

      _updateCurrentSectorLabel();
    } catch (e) {
      _sectors = [];
      _snack('Erro ao carregar setores: $e');
    }
    if (mounted) {
      setState(() => _isLoadingSectors = false);
    }
  }

  void _updateCurrentSectorLabel() {
    final sector = ProductionManager.instance.getSectorModelById(_sector);
    _currentSectorLabel = sector?.label ?? _sector;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ✅ NOVO: Converter Timestamps
  Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.value is Timestamp) {
        result[entry.key] =
            (entry.value as Timestamp).toDate().toIso8601String();
      } else if (entry.value is Map) {
        result[entry.key] =
            _convertTimestampsToStrings(entry.value as Map<String, dynamic>);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<String, dynamic>? _parseQr(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        final map = decoded;
        final id = (map['id'] ?? map['ticketId'] ?? '').toString();
        final modelo = (map['modelo'] ?? '').toString();
        final cor = (map['cor'] ?? '').toString();
        final marca = (map['marca'] ?? '').toString();
        final referencia = (map['referencia'] ?? '').toString();
        final pairs =
            int.tryParse((map['pairs'] ?? map['total'] ?? '0').toString()) ?? 0;

        if (id.isNotEmpty && pairs > 0) {
          return {
            'id': id,
            'modelo': modelo,
            'cor': cor,
            'marca': marca,
            'referencia': referencia,
            'pairs': pairs,
          };
        }
      }
    } catch (_) {}

    final parts = raw.split('|');
    if (parts.length >= 6 && parts[0].toUpperCase() == 'TKT') {
      final id = parts[1].trim();
      final modelo = parts[2].trim();
      final cor = parts[3].trim();
      final referencia = parts[4].trim();
      final pairs = int.tryParse(parts[5].trim()) ?? 0;

      if (id.isNotEmpty && pairs > 0) {
        return {
          'id': id,
          'modelo': modelo,
          'cor': cor,
          'marca': '',
          'referencia': referencia,
          'pairs': pairs,
        };
      }
    }
    return null;
  }

  Future<bool> _darEntrada(Map<String, dynamic> p) async {
    try {
      final result = await ProductionManager.instance.entrada(
        ticketData: p,
        sectorId: _sector,
        teamId: widget.user.teamId,
      );
      _snack(result
          ? 'Ficha ${p['id']}: Entrada com sucesso.'
          : 'Erro: não foi possível dar entrada.');
      return result;
    } catch (e) {
      _snack('ERRO ao dar entrada: ${e.toString()}');
      return false;
    }
  }

  Future<bool> _darSaidaOuFinalizar(Map<String, dynamic> p) async {
    try {
      final result = await ProductionManager.instance.saida(
        ticketData: p,
        sectorId: _sector,
        teamId: widget.user.teamId,
      );
      _snack(result
          ? 'Ficha ${p['id']}: Saída com sucesso.'
          : 'Erro: não foi possível dar saída.');
      return result;
    } catch (e) {
      _snack('ERRO ao dar saída: ${e.toString()}');
      return false;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    final duration = msg.startsWith('ERRO')
        ? const Duration(seconds: 4)
        : (msg == 'Cancelado.'
            ? const Duration(seconds: 1)
            : const Duration(seconds: 2));

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: duration));
  }

  Future<void> _handleScan(String raw) async {
    if (_handling) return;
    setState(() => _handling = true);

    final parsed = _parseQr(raw);
    setState(() {
      _lastParsed = parsed;
    });

    if (parsed == null) {
      _snack(
          'QR inválido. Formato esperado: TKT|id|modelo|cor|referencia|total');
      setState(() => _handling = false);
      return;
    }

    final action = await showModalBottomSheet<String?>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.login, color: Colors.blue, size: 32),
              title: const Text('Dar ENTRADA'),
              subtitle: Text('Setor: $_currentSectorLabel'),
              onTap: () => Navigator.pop(c, 'entrada'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.green, size: 32),
              title: const Text('Finalizar e Dar SAÍDA'),
              subtitle: Text('Registra a produção ($_currentSectorLabel)'),
              onTap: () => Navigator.pop(c, 'saida'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(c, null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    try {
      if (action == 'entrada') {
        await _darEntrada(parsed);
      } else if (action == 'saida') {
        await _darSaidaOuFinalizar(parsed);
      } else {
        _snack('Cancelado.');
      }
    } catch (e) {
      _snack('ERRO CRÍTICO: ${e.toString()}');
    } finally {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _handling = false);
      // ✅ CORREÇÃO: NÃO FECHA AUTOMATICAMENTE!
      // Remove esta linha: if (mounted && !_isFullScreen) Navigator.pop(context);
    }
  }

  // ✅ CORRIGIDO
  Future<Map<String, dynamic>?> _getTicketDataById(String ticketId) async {
    try {
      final Map<String, dynamic>? ticketData =
          await ProductionManager.instance.getTicketDataFromFirebase(ticketId);

      if (ticketData != null) {
        ticketData['referencia'] ??= '';
        ticketData['modelo'] ??= '';
        ticketData['cor'] ??= '';
        ticketData['marca'] ??= '';

        // ✅ Converter Timestamps
        return _convertTimestampsToStrings(ticketData);
      }
      _snack('ERRO: Ficha com ID "$ticketId" não encontrada na nuvem.');
      return null;
    } catch (e) {
      _snack('Erro ao buscar dados da ficha na nuvem: $e');
      debugPrint('Erro completo: $e');
      return null;
    }
  }

  Widget _buildReticle() {
    return Center(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final opacity = 0.5 + 0.5 * _animController.value;
          return IgnorePointer(
            child: Container(
              width: previewHeight * 0.6,
              height: previewHeight * 0.6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withOpacity(opacity), width: 2),
                color: Colors.black
                    .withOpacity(0.12 * (1 - _animController.value)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smartphone, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Scanner de QR Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Disponível apenas no aplicativo mobile',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 24),
            Text(
              'Use "Entrada Manual" para testar',
              style: TextStyle(color: Colors.amber, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview({required double height}) {
    if (kIsWeb) {
      return _buildWebFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller!,
            fit: BoxFit.cover,
            onDetect: (capture) {
              final code = (capture.barcodes.isNotEmpty)
                  ? capture.barcodes.first.rawValue
                  : null;
              if (code != null) {
                _handleScan(code);
              }
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          _buildReticle(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.55;
    final double calcHeight = previewHeight.clamp(200.0, maxHeight);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor de QR'),
        actions: [
          if (_isLoadingSectors)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white)),
            )
          else if (_sectors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sector,
                  items: _sectors
                      .map((s) => DropdownMenuItem(
                            value: s.firestoreId,
                            child: Text(s.label.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _sector = v;
                        _updateCurrentSectorLabel();
                      });
                    }
                  },
                ),
              ),
            ),
          if (!kIsWeb) ...[
            IconButton(
              tooltip: 'Alternar flash',
              icon: const Icon(Icons.flash_on),
              onPressed: () async {
                try {
                  await _controller?.toggleTorch();
                } catch (_) {}
              },
            ),
            IconButton(
              tooltip: 'Câmera frontal/traseira',
              icon: const Icon(Icons.cameraswitch),
              onPressed: () async {
                try {
                  await _controller?.switchCamera();
                } catch (_) {}
              },
            ),
          ],
          IconButton(
            tooltip:
                _isFullScreen ? 'Sair do modo tela cheia' : 'Abrir tela cheia',
            icon:
                Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () {
              setState(() {
                _isFullScreen = !_isFullScreen;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                kIsWeb
                    ? 'Use "Entrada Manual" para testar na web'
                    : 'Aponte o QR para dentro do retículo',
                style: TextStyle(
                  fontSize: 14,
                  color: kIsWeb ? Colors.amber : null,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isFullScreen
                    ? double.infinity
                    : MediaQuery.of(context).size.width * 0.9,
                height: _isFullScreen
                    ? MediaQuery.of(context).size.height * 0.72
                    : calcHeight,
                margin:
                    EdgeInsets.symmetric(horizontal: _isFullScreen ? 0 : 16),
                child: _buildCameraPreview(height: calcHeight),
              ),
              const SizedBox(height: 12),
              if (_lastParsed != null)
                _LastScanCard(
                    data: _lastParsed!, sectorLabel: _currentSectorLabel),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _snack('Cancelado.');
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Fechar'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final String? manualId = await showDialog<String?>(
                              context: context,
                              builder: (c) {
                                final idCtl = TextEditingController();
                                return AlertDialog(
                                  title: const Text(
                                      'Entrada Manual (ID da Ficha)'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: idCtl,
                                        decoration: const InputDecoration(
                                          labelText: 'ID da Ficha',
                                          hintText: 'Ex: 2025-003',
                                        ),
                                        autofocus: true,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        final id = idCtl.text.trim();
                                        if (id.isNotEmpty) {
                                          Navigator.pop(c, id);
                                        } else {
                                          Navigator.pop(c);
                                        }
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (manualId != null && manualId.isNotEmpty) {
                              final Map<String, dynamic>? ticketData =
                                  await _getTicketDataById(manualId);

                              if (ticketData != null) {
                                // ✅ CORRIGIDO: ticketData já está sem Timestamps
                                try {
                                  await _handleScan(json.encode(ticketData));
                                } catch (e) {
                                  _snack('Erro ao processar ficha: $e');
                                  debugPrint('Erro ao encodar: $e');
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Entrada manual'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastScanCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String sectorLabel;

  const _LastScanCard({required this.data, required this.sectorLabel});

  @override
  Widget build(BuildContext context) {
    final id = data['id']?.toString() ?? '';
    final modelo = (data['modelo'] ?? '').toString();
    final cor = (data['cor'] ?? '').toString();
    final marca = (data['marca'] ?? '').toString();
    final referencia = (data['referencia'] ?? '').toString();
    final pairs = (data['pairs'] is int)
        ? data['pairs'] as int
        : int.tryParse(data['pairs']?.toString() ?? '0') ?? 0;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.qr_code_2, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ficha $id',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (modelo.isNotEmpty) Text('Modelo: $modelo'),
                      if (cor.isNotEmpty) Text('Cor: $cor'),
                      if (referencia.isNotEmpty) Text('Ref: $referencia'),
                      if (marca.isNotEmpty) Text('Marca: $marca'),
                      Text('Pares: $pairs'),
                      Text('Setor: ${sectorLabel.toUpperCase()}'),
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
