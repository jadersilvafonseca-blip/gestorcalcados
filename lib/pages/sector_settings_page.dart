import 'package:flutter/material.dart';
// import 'package:hive/hive.dart'; // REMOVIDO
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// --- MUDANÇA: Importa o modelo do usuário ---
import '../models/app_user_model.dart';
// --- FIM DA MUDANÇA ---

import '../models/sector_models.dart';
import '../services/production_manager.dart';
import '../services/icon_picker_service.dart';
// import 'dashboard_page.dart' show kSettingsBox, kMainSectorKey; // REMOVIDO

class SectorSettingsPage extends StatefulWidget {
  // --- MUDANÇA: Recebe o usuário (para sabermos o teamId) ---
  final AppUserModel user;
  const SectorSettingsPage({super.key, required this.user});
  // --- FIM DA MUDANÇA ---

  @override
  State<SectorSettingsPage> createState() => _SectorSettingsPageState();
}

class _SectorSettingsPageState extends State<SectorSettingsPage> {
  List<ConfigurableSector> _sectors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSectors();
  }

  // --- MUDANÇA: Passa o teamId para o PM ---
  Future<void> _loadSectors() async {
    setState(() {
      _isLoading = true;
    });

    final pm = ProductionManager.instance;
    // Agora busca os setores APENAS deste time
    _sectors = await pm.getAllSectorModels(widget.user.teamId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // --- FIM DA MUDANÇA ---

  IconData _iconFromSector(ConfigurableSector sector) {
    final cp = sector.iconCodePoint;
    return IconData(cp, fontFamily: 'MaterialIcons');
  }

  Color _colorFromSector(ConfigurableSector sector) {
    final val = sector.colorValue;
    return Color(val);
  }

  void _showEditSectorDialog([ConfigurableSector? sectorToEdit]) async {
    final bool isEditing = sectorToEdit != null;
    final pm = ProductionManager.instance;

    String label = sectorToEdit?.label ?? '';
    String firestoreId = sectorToEdit?.firestoreId ?? '';
    Color color =
        sectorToEdit != null ? _colorFromSector(sectorToEdit) : Colors.blue;
    IconData icon =
        sectorToEdit != null ? _iconFromSector(sectorToEdit) : Icons.settings;

    final result = await showDialog<ConfigurableSector>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isIdEditable = !isEditing;

            return AlertDialog(
              title: Text(isEditing
                  ? 'Editar Setor: ${sectorToEdit.label}'
                  : 'Novo Setor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: label,
                      decoration: const InputDecoration(
                          labelText: 'Nome do Setor (ex: Montagem)'),
                      onChanged: (value) => label = value.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: firestoreId,
                      readOnly: !isIdEditable,
                      decoration: InputDecoration(
                        labelText:
                            'ID Único (Para Integração, sem acento/espaço)',
                        helperText: isIdEditable
                            ? 'Ex: montagem_final'
                            : 'ID não pode ser alterado.',
                      ),
                      onChanged: (value) => firestoreId =
                          value.trim().toLowerCase().replaceAll(' ', '_'),
                    ),
                    const SizedBox(height: 20),
                    // --- Seletor de Ícone ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ícone:',
                            style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          icon: Icon(icon, color: color),
                          iconSize: 32,
                          onPressed: () async {
                            final newIcon =
                                await IconPickerService.showIconPicker(context,
                                    currentIcon: icon);
                            if (newIcon != null) {
                              setStateDialog(() => icon = newIcon);
                            }
                          },
                        ),
                      ],
                    ),
                    // --- Seletor de Cor ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cor:',
                            style: Theme.of(context).textTheme.titleMedium),
                        TextButton(
                          onPressed: () async {
                            final newColor = await _showColorPickerDialog(
                                context,
                                currentColor: color);
                            if (newColor != null) {
                              setStateDialog(() => color = newColor);
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () async {
                    // getSectorModelById (síncrono) lê do cache que
                    // _loadSectors(teamId) já carregou.
                    if (!isEditing &&
                        pm.getSectorModelById(firestoreId) != null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Este ID já está sendo usado.')));
                      return;
                    }
                    if (label.isEmpty || firestoreId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Preencha o Nome e o ID do setor.')));
                      return;
                    }

                    ConfigurableSector newSector;
                    if (isEditing) {
                      newSector = sectorToEdit.copyWith(
                        label: label,
                        iconCodePoint: icon.codePoint,
                        colorValue: color.value,
                      );
                    } else {
                      newSector = ConfigurableSector(
                        firestoreId: firestoreId,
                        label: label,
                        iconCodePoint: icon.codePoint,
                        colorValue: color.value,
                      );
                    }
                    Navigator.pop(context, newSector);
                  },
                  child: Text(isEditing ? 'Salvar Edição' : 'Criar Setor'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      // --- MUDANÇA: Passa o teamId para o PM ---
      await pm.saveSectorModel(result, widget.user.teamId);
      // --- FIM DA MUDANÇA ---
      ProductionManager.instance.refreshSectorCache();
      _loadSectors(); // Recarrega a lista
    }
  }

  /// Abre o Color Picker (Não precisa de mudança)
  Future<Color?> _showColorPickerDialog(BuildContext context,
      {required Color currentColor}) {
    Color selectedColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecione uma cor'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) => selectedColor = color,
            ),
          ),
          actions: <Widget>[
            TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop()),
            FilledButton(
                child: const Text('Selecionar'),
                onPressed: () => Navigator.of(context).pop(selectedColor)),
          ],
        );
      },
    );
  }

  // --- MUDANÇA: Remoção da lógica do Hive ---
  void _confirmDeleteSector(ConfigurableSector sector) async {
    // A verificação do "Setor Principal" foi removida
    // pois dependia de uma "Box" (kSettingsBox) do Hive.

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Setor?'),
        content:
            Text('Tem certeza que deseja excluir o setor "${sector.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      // --- MUDANÇA: Passa o teamId para o PM ---
      await ProductionManager.instance
          .deleteSectorModel(sector.firestoreId, widget.user.teamId);
      // --- FIM DA MUDANÇA ---
      ProductionManager.instance.refreshSectorCache();
      _loadSectors(); // Recarrega a lista
    }
  }

  // --- MUDANÇA: Passa o teamId para o PM ---
  void _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final ConfigurableSector item = _sectors.removeAt(oldIndex);
    _sectors.insert(newIndex, item);

    setState(() {});

    final List<String> orderedIds = _sectors.map((s) => s.firestoreId).toList();

    // SALVANDO A ORDEM no PM com o teamId
    await ProductionManager.instance
        .saveSectorOrder(orderedIds, widget.user.teamId);

    ProductionManager.instance.refreshSectorCache();
  }
  // --- FIM DA MUDANÇA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração de Setores'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Arraste e solte o identificador (:::) para reordenar os setores no Dashboard.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: ReorderableListView(
                    onReorder: _onReorder,
                    children: _sectors.map((sector) {
                      final icon = _iconFromSector(sector);
                      final color = _colorFromSector(sector);
                      return Card(
                        key: ValueKey(sector.firestoreId), // Chave Única
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: ListTile(
                          tileColor: color.withOpacity(0.05),
                          leading: Icon(icon, color: color),
                          title: Text(sector.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${sector.firestoreId}'),
                          trailing: ReorderableDragStartListener(
                            index: _sectors.indexOf(sector),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _showEditSectorDialog(sector),
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _confirmDeleteSector(sector),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Icon(Icons.drag_handle,
                                      color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditSectorDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
