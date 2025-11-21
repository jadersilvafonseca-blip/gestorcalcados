// lib/services/icon_picker_service.dart

import 'package:flutter/material.dart';
import '../ui/icon_picker_dialog.dart'; // <<< Importa o diálogo da cartela

class IconPickerService {
  /// Abre o diálogo modal para selecionar um IconData.
  static Future<IconData?> showIconPicker(
    BuildContext context, {
    IconData? currentIcon,
  }) async {
    // CORREÇÃO: Abre o IconPickerDialog real em vez do diálogo MOCK
    return showDialog<IconData>(
      context: context,
      builder: (BuildContext context) {
        return IconPickerDialog(currentIcon: currentIcon);
      },
    );
  }
}
