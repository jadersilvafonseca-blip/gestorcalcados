// lib/ui/icon_picker_dialog.dart

import 'package:flutter/material.dart';

// Lista de ícones para exibição (Você pode adicionar mais se necessário)
const List<IconData> kSectorIcons = [
  Icons.inventory_2_outlined, // Estoque / Almoxarifado
  Icons.content_cut, // Corte
  Icons.straighten_outlined, // Pesponto
  Icons.table_chart_outlined, // Banca / Mesa
  Icons.layers_outlined, // Montagem
  Icons.local_shipping_outlined, // Expedição / Logística
  Icons.settings_outlined, // Padrão
  Icons.factory_outlined,
  Icons.precision_manufacturing_outlined,
  Icons.group_work_outlined,
  Icons.view_module_outlined,
  Icons.storage_outlined,

  // CORREÇÃO: Substituindo Icons.pallet_outlined por um ícone existente (Icons.warehouse_outlined)
  Icons.warehouse_outlined,

  Icons.dry_cleaning_outlined,
  Icons.local_library_outlined,
  Icons.bolt_outlined,
  Icons.speed_outlined,
];

class IconPickerDialog extends StatefulWidget {
  final IconData? currentIcon;

  const IconPickerDialog({super.key, this.currentIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  IconData _selectedIcon = kSectorIcons.first;

  @override
  void initState() {
    super.initState();
    // Garante que o ícone atual esteja selecionado ao abrir
    if (widget.currentIcon != null &&
        kSectorIcons.contains(widget.currentIcon)) {
      _selectedIcon = widget.currentIcon!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecione um Ícone'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: kSectorIcons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final icon = kSectorIcons[index];
            final isSelected = icon == _selectedIcon;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIcon = icon;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).primaryColor, width: 2)
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade700,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedIcon),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
