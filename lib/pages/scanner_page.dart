// lib/pages/scanner_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/hive_service.dart';
import '../models/ticket.dart';
import '../models/sector_models.dart'; // Importa o modelo oficial de setores

/// Boxes auxiliares
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';

class ScannerPage extends StatefulWidget {
  final String sectorId; // ID do setor (ex: 'banca 1')

  const ScannerPage({
    super.key,
    required this.sectorId, // Agora é obrigatório
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
    _prepareBoxes();
  }

  Future<void> _prepareBoxes() async {
    await HiveService.init();
    if (!Hive.isBoxOpen(kMovementsBox)) {
      await Hive.openBox(kMovementsBox);
    }
    if (!Hive.isBoxOpen(kSectorDailyBox)) {
      await Hive.openBox(kSectorDailyBox);
    }
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

  // -------------------- HIVE HELPERS --------------------
  Box get _movBox => Hive.box(kMovementsBox);
  Box get _dailyBox => Hive.box(kSectorDailyBox);

  String _openKey(String ticketId) => 'open::$ticketId::$_sector';
  String _histKey(String ticketId) => 'hist::$ticketId';
  String _prodKey(String dateYmd) => '$_sector::$dateYmd';
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _ensureTicketExists(Map<String, dynamic> p) async {
    final all = HiveService.getAllTickets();
    final exists = all.any((e) {
      return e.id == p['id'];
    });

    if (!exists) {
      final t = Ticket(
        id: p['id'],
        cliente: '',
        modelo: (p['modelo'] ?? '').toString(),
        marca: (p['marca'] ?? '').toString(),
        cor: (p['cor'] ?? '').toString(),
        pairs: p['pairs'] as int,
        grade: <String, int>{},
        observacao: '',
        pedido: '',
      );
      // Envolve a adição em try/catch para segurança
      try {
        await HiveService.addTicket(t);
      } catch (e) {
        // Se falhar ao adicionar, pelo menos avisa
        _snack('Erro ao salvar nova ficha: ${e.toString()}');
      }
    }
  }

  // --------------------------------------------------------------------
  // FUNÇÃO _darEntrada (TORNADA MAIS SEGURA com try/catch)
  // --------------------------------------------------------------------
  Future<bool> _darEntrada(Map<String, dynamic> p) async {
    try {
      await _ensureTicketExists(p);
      final ticketId = p['id'].toString();

      // 1. Procura por esta ficha aberta em QUALQUER setor
      String? setorAberto;
      for (final k in _movBox.keys) {
        if (k is String && k.startsWith('open::$ticketId::')) {
          final parts = k.split('::');
          if (parts.length == 3) {
            setorAberto = parts[2];
            break;
          }
        }
      }

      if (setorAberto != null) {
        if (setorAberto == _sector) {
          _snack('Esta ficha já está em processo neste setor.');
        } else {
          final labelSetorAberto =
              sectorFromFirestoreId(setorAberto)?.label ?? setorAberto;
          _snack(
              'ERRO: Ficha ainda está aberta no setor [$labelSetorAberto]. Dê saída por lá primeiro.');
        }
        return false;
      }

      // 3. (REGRA) Verifica se a ficha já saiu DESTE setor (no histórico)
      final hk = _histKey(ticketId);
      final hist = (_movBox.get(hk) as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];

      final bool jaSaiuDesteSetor = hist.any((mov) {
        return mov.containsKey('sector') && mov['sector'] == _sector;
      });

      if (jaSaiuDesteSetor) {
        _snack(
            'ERRO: Ficha $ticketId já foi finalizada neste setor e não pode entrar novamente.');
        return false;
      }

      // 4. Se passou, pode dar entrada (operação crítica):
      final key = _openKey(ticketId);
      await _movBox.put(key, {
        'ticketId': ticketId,
        'sector': _sector,
        'pairs': p['pairs'],
        'inAt': DateTime.now().toIso8601String(),
      });

      _snack('Ficha $ticketId: Entrada com sucesso.');
      return true; // Sucesso
    } catch (e) {
      _snack('ERRO ao dar entrada: ${e.toString()}');
      return false; // Falha
    }
  }

  // --------------------------------------------------------------------
  // FUNÇÃO _darSaidaOuFinalizar (TORNADA MAIS SEGURA com try/catch)
  // --------------------------------------------------------------------
  Future<bool> _darSaidaOuFinalizar(Map<String, dynamic> p) async {
    try {
      final key = _openKey(p['id']);
      final open = _movBox.get(key);

      if (open == null) {
        _snack('Nenhuma entrada aberta desta ficha neste setor.');
        return false; // Falha esperada
      }

      // --- Início das Operações Críticas ---

      // 1. Prepara dados
      final outAt = DateTime.now();
      final movClosed = Map<String, dynamic>.from(open);
      movClosed['outAt'] = outAt.toIso8601String();

      // 2. Salva no histórico
      final hk = _histKey(p['id']);
      final hist = (_movBox.get(hk) as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      hist.add(movClosed);
      await _movBox.put(hk, hist);

      // 3. Remove o "aberto"
      await _movBox.delete(key);

      // 4. Soma produção diária
      final ymd = _ymd(outAt);
      final pk = _prodKey(ymd);
      final current = (_dailyBox.get(pk) as int?) ?? 0;
      final produced = (open['pairs'] as int?) ?? (p['pairs'] as int);
      await _dailyBox.put(pk, current + produced);

      // --- Fim das Operações Críticas ---

      _snack('Ficha ${p['id']}: Saída com sucesso.');
      return true; // Sucesso
    } catch (e) {
      _snack('ERRO ao dar saída: ${e.toString()}');
      return false; // Falha
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

    // --- Caso 1: QR Inválido ---
    if (parsed == null) {
      _snack('QR inválido. Formato esperado: TK|id|modelo|cor|marca|total');
      setState(() => _handling = false); // Libera para nova tentativa
      return; // <-- Não fecha a tela
    }

    // --- Caso 2: QR Válido ---
    final currentSectorLabel = sectorFromFirestoreId(_sector)?.label ?? _sector;
    final ticketId = parsed['id'].toString();
    final key = _openKey(ticketId);
    final openMovement = _movBox.get(key);
    final bool isInThisSector = openMovement != null;

    if (!mounted) {
      setState(() => _handling = false);
      return;
    }

    // Mostra o popup
    final action = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInThisSector)
              ListTile(
                leading:
                    const Icon(Icons.logout, color: Colors.green, size: 32),
                title: const Text('Finalizar e Dar SAÍDA'),
                subtitle: Text('Registra a produção ($currentSectorLabel)'),
                onTap: () => Navigator.pop(c, 'saida'),
              )
            else
              ListTile(
                leading: const Icon(Icons.login, color: Colors.blue, size: 32),
                title: const Text('Dar ENTRADA'),
                subtitle: Text('Setor: $currentSectorLabel'),
                onTap: () => Navigator.pop(c, 'entrada'),
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

    // --- Processa a Ação ---
    try {
      if (action == 'entrada') {
        await _darEntrada(parsed);
      } else if (action == 'saida') {
        await _darSaidaOuFinalizar(parsed);
      } else if (action == null) {
        _snack('Cancelado.');
      }
    } catch (e) {
      _snack('ERRO CRÍTICO: ${e.toString()}');
    } finally {
      // Damos um delay mínimo para o usuário ler o snack
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        Navigator.pop(context); // Fecha a tela do scanner
      }
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final movementsReady = Hive.isBoxOpen(kMovementsBox);
    final dailyReady = Hive.isBoxOpen(kSectorDailyBox);

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
          if (!(movementsReady && dailyReady))
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'Inicializando armazenamento local...',
                style: TextStyle(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}

//
// ====================================================================
// <<< CLASSE _LastScanCard CORRIGIDA E COMPLETA >>>
// ====================================================================
//
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
                      Text(
                        'Setor: ${sectorLabel.toUpperCase()}',
                      ),
                    ],
                  ), // Fecha o Wrap
                ], // Fecha o children do Column
              ), // Fecha o Column
            ), // Fecha o Expanded
          ], // Fecha o children do Row
        ), // Fecha o Padding
      ), // Fecha o Card
    ); // Fecha o return
  } // Fecha o método build
} // Fecha a classe _LastScanCard
