// lib/pages/sector_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:gestor_calcados_new/models/sector_models.dart';

class SectorDetailPage extends StatefulWidget {
  final SectorModel sectorModel;
  const SectorDetailPage({super.key, required this.sectorModel});

  @override
  State<SectorDetailPage> createState() => _SectorDetailPageState();
}

class _SectorDetailPageState extends State<SectorDetailPage> {
  late SectorModel _data;

  @override
  void initState() {
    super.initState();
    _data = widget.sectorModel;
  }

  String get _agoraFull =>
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  // ======== SCANNER (ENTRADA/SAÍDA) ========
  Future<void> _openScanner({required bool entrada}) async {
    bool fired = false; // evita múltiplos pops
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
      ],
    );

    try {
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        barrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Padding(
                padding: MediaQuery.of(ctx).viewInsets,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entrada ? 'Dar ENTRADA' : 'Dar SAÍDA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(
                          controller: controller,
                          onDetect: (cap) async {
                            if (fired) return;
                            final bc = cap.barcodes.isNotEmpty
                                ? (cap.barcodes.first.rawValue ??
                                    cap.barcodes.first.displayValue)
                                : null;
                            if (bc == null) return;
                            fired = true;
                            try {
                              await controller.stop();
                            } catch (_) {}
                            if (ctx.mounted) Navigator.pop(ctx, bc);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Lanterna',
                          onPressed: () async {
                            try {
                              await controller.toggleTorch();
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Falha na lanterna: $e'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
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
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Falha ao trocar câmera: $e'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.cameraswitch),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      );

      // garante fechamento do controller
      try {
        controller.dispose();
      } catch (_) {}

      if (!mounted || code == null) return;

      // TODO: interpretar o QR para decidir quantidade e ficha
      // Exemplo provisório: usa 10 como quantidade fixa
      const int qtd = 10;

      // Aplica a atualização local
      final novoEmProducao = entrada
          ? _data.emProducao + qtd
          : (_data.emProducao - qtd).clamp(0, 1 << 31);
      final novoProducaoDia =
          entrada ? _data.producaoDia : _data.producaoDia + qtd;

      setState(() {
        _data = _data.copyWith(
          emProducao: novoEmProducao,
          producaoDia: novoProducaoDia,
          atualizacao: DateTime.now(),
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entrada
                ? 'Entrada registrada! (QR: $code)'
                : 'Saída registrada! (QR: $code)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // DICA: aqui seria o ponto de persistir no Firestore (update no setor)
      // await FirebaseFirestore.instance.collection('sectors').doc(_data.sector.name).update({
      //   'emProducao': novoEmProducao,
      //   'producaoDia': novoProducaoDia,
      //   'atualizacao': FieldValue.serverTimestamp(),
      // });
    } catch (e) {
      try {
        controller.dispose();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao abrir o scanner: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ======== GARGALO ========
  Future<void> _openGargaloDialog() async {
    // estado local do dialog
    final motivos = <String, bool>{
      'Falta de funcionários': false,
      'Máquina estragada': false,
      'Peça com defeito (Reposição)': false,
      'Falta de energia': false,
      'Acidente': false,
    };
    final textoCtrl = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Registrar gargalo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...motivos.keys.map(
                      (k) => CheckboxListTile(
                        value: motivos[k],
                        onChanged: (v) =>
                            setDialogState(() => motivos[k] = v ?? false),
                        title: Text(k),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (ok == true) {
      // Aqui você poderia salvar no Firestore uma ocorrência de gargalo
      // (set/add em 'sector_issues' com setor, motivos e observações)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gargalo registrado e notificação enviada!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    textoCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Setor: ${_data.sector.label}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              title: const Text('Produção do dia (pares)'),
              subtitle: Text(
                '${_data.producaoDia}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              trailing: Text(_agoraFull),
            ),
          ),
          const SizedBox(height: 12),
          Text('Ações', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openScanner(entrada: true),
                icon: const Icon(Icons.login),
                label: const Text('Dar entrada'),
              ),
              ElevatedButton.icon(
                onPressed: () => _openScanner(entrada: false),
                icon: const Icon(Icons.logout),
                label: const Text('Dar saída'),
              ),
              OutlinedButton.icon(
                onPressed: _openGargaloDialog,
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Gargalo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Status do setor'),
              subtitle: Text(
                'Em produção: ${_data.emProducao}  •  '
                'Atualizado: ${DateFormat('HH:mm').format(_data.atualizacao)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
