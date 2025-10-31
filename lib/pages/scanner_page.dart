// lib/pages/scanner_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/production_manager.dart';
import '../models/sector_models.dart';

class ScannerPage extends StatefulWidget {
  final String sectorId; // ID do setor (ex: 'banca 1')

  const ScannerPage({
    super.key,
    required this.sectorId, // Obrigatório
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false; // Trava para evitar scans duplicados

  late String _sector;
  Map<String, dynamic>? _lastParsed;

  @override
  void initState() {
    super.initState();
    _sector = widget.sectorId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -------------------- PARSER --------------------
  Map<String, dynamic>? _parseQr(String raw) {
    // tenta JSON
    try {
      final map = json.decode(raw);
      final id = (map['id'] ?? map['ticketId'] ?? '').toString();
      final modelo = (map['modelo'] ?? '').toString();
      final cor = (map['cor'] ?? '').toString();
      final marca = (map['marca'] ?? '').toString();
      final pairs =
          int.tryParse((map['pairs'] ?? map['total'] ?? '0').toString()) ?? 0;
      if (id.isNotEmpty && pairs > 0) {
        return {
          'id': id,
          'modelo': modelo,
          'cor': cor,
          'marca': marca,
          'pairs': pairs,
        };
      }
    } catch (_) {
      // ignore e tenta pipe
    }

    // tenta pipe: TK|id|modelo|cor|marca|total
    final parts = raw.split('|');
    if (parts.length >= 6 && parts[0].toUpperCase() == 'TK') {
      final id = parts[1].trim();
      final modelo = parts[2].trim();
      final cor = parts[3].trim();
      final marca = parts[4].trim();
      final pairs = int.tryParse(parts[5].trim()) ?? 0;
      if (id.isNotEmpty && pairs > 0) {
        return {
          'id': id,
          'modelo': modelo,
          'cor': cor,
          'marca': marca,
          'pairs': pairs,
        };
      }
    }
    return null;
  }

  // -------------------- ENTRADA / SAÍDA --------------------
  Future<bool> _darEntrada(Map<String, dynamic> p) async {
    try {
      final result =
          await ProductionManager().entrada(ticketData: p, sectorId: _sector);
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
      final result =
          await ProductionManager().saida(ticketData: p, sectorId: _sector);
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
    final duration = msg.startsWith('ERRO:')
        ? const Duration(seconds: 4)
        : (msg == 'Cancelado.'
            ? const Duration(seconds: 1)
            : const Duration(seconds: 2));

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: duration));
  }

  // -------------------- SCAN HANDLER --------------------
  Future<void> _handleScan(String raw) async {
    if (_handling) return;
    setState(() => _handling = true);

    final parsed = _parseQr(raw);
    setState(() {
      _lastParsed = parsed;
    });

    if (parsed == null) {
      _snack('QR inválido. Formato esperado: TK|id|modelo|cor|marca|total');
      setState(() => _handling = false);
      return;
    }

    final currentSectorLabel = sectorFromFirestoreId(_sector)?.label ?? _sector;

    // Mostra o popup
    final action = await showModalBottomSheet<String>(
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
              subtitle: Text('Setor: $currentSectorLabel'),
              onTap: () => Navigator.pop(c, 'entrada'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.green, size: 32),
              title: const Text('Finalizar e Dar SAÍDA'),
              subtitle: Text('Registra a produção ($currentSectorLabel)'),
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
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        Navigator.pop(context); // Fecha scanner
      }
      setState(() => _handling = false);
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final currentSectorLabel = sectorFromFirestoreId(_sector)?.label ?? _sector;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor de QR'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sector,
                items: Sector.values
                    .map((s) => DropdownMenuItem(
                          value: s.firestoreId,
                          child: Text(s.label.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _sector = v);
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Alternar flash',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Câmera frontal/traseira',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null) _handleScan(code);
              },
            ),
          ),
          if (_lastParsed != null)
            _LastScanCard(data: _lastParsed!, sectorLabel: currentSectorLabel),
        ],
      ),
    );
  }
}

// ====================================================================
// <<< CLASSE _LastScanCard >>> (UI do último scan)
// ====================================================================
class _LastScanCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String sectorLabel;

  const _LastScanCard({required this.data, required this.sectorLabel});

  @override
  Widget build(BuildContext context) {
    final id = data['id'];
    final modelo = (data['modelo'] ?? '').toString();
    final cor = (data['cor'] ?? '').toString();
    final marca = (data['marca'] ?? '').toString();
    final pairs = data['pairs'];

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
