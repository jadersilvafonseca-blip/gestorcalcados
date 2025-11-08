import 'dart:convert';
import 'dart:io'; // Necessário para File
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; // Para carregar o backup
import 'package:path_provider/path_provider.dart'; // Para salvar o backup
import 'package:share_plus/share_plus.dart'; // Para compartilhar o backup

// Definindo os nomes das boxes aqui para referência
const String kTicketsBox = 'tickets_box';
const String kProductsBox = 'products_box';
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';
const String kBottlenecksActiveBox = 'bottlenecks_active_box';
const String kBottlenecksHistoryBox = 'bottlenecks_history_box';

// Lista de todas as boxes que o app usa
const List<String> _allBoxNames = [
  kTicketsBox,
  kProductsBox,
  kMovementsBox,
  kSectorDailyBox,
  kBottlenecksActiveBox,
  kBottlenecksHistoryBox,
];

class BackupService {
  /// Gera um backup de todas as boxes do Hive como um arquivo .json e o compartilha.
  static Future<void> generateBackup(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando backup, por favor aguarde...')),
    );

    try {
      final Map<String, dynamic> allData = {};

      for (String boxName in _allBoxNames) {
        if (!Hive.isBoxOpen(boxName)) {
          try {
            await Hive.openBox<dynamic>(boxName);
          } catch (e) {
            continue; // Pula boxes que não existem
          }
        }
        final box = Hive.box<dynamic>(boxName);

        // Converte o mapa do Hive para um formato JSON seguro
        final Map<String, dynamic> safeMap = {};
        final rawMap = box.toMap();
        rawMap.forEach((key, value) {
          safeMap[key.toString()] = value;
        });

        allData[boxName] = safeMap;
      }

      // Codifica o Map gigante em uma string JSON formatada
      final String backupJson =
          const JsonEncoder.withIndent('  ').convert(allData);

      // --- NOVA LÓGICA PARA SALVAR ARQUIVO .JSON ---

      // 1. Encontra o diretório temporário
      final directory = await getTemporaryDirectory();
      final dateFile = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String fileName = 'backup_gestor_calcados_$dateFile.json';
      final String filePath = '${directory.path}/$fileName';

      // 2. Cria e escreve o arquivo .json
      final file = File(filePath);
      await file.writeAsString(backupJson);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 3. Abre a tela de compartilhamento do celular
      // (Usando Share.shareXFiles para compartilhar o arquivo)
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Backup dos dados do Gestor Calçados - $dateFile',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar backup: ${e.toString()}')),
      );
    }
  }

  // =========================================================
  // --- FUNÇÃO DE RESTAURAR BACKUP ATUALIZADA (para .json) ---
  // =========================================================

  /// Inicia o processo de restauração de backup a partir de um .json.
  static Future<void> restoreBackup(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selecione o arquivo .json de backup...')),
    );

    try {
      // 1. PEDE AO USUÁRIO PARA ESCOLHER O ARQUIVO JSON
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'], // <-- SÓ PERMITE ARQUIVOS .json
      );

      if (result == null || result.files.single.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum arquivo selecionado.')),
        );
        return;
      }

      File file = File(result.files.single.path!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lendo arquivo de backup...')),
      );

      // 2. LÊ O ARQUIVO DE TEXTO (JSON)
      String jsonText = await file.readAsString();
      if (jsonText.isEmpty) {
        throw Exception(
            'Este arquivo .json não contém um backup válido ou está corrompido.');
      }

      // 3. CONVERTE O TEXTO JSON PARA UM MAPA
      Map<String, dynamic> backupData = json.decode(jsonText);

      // 4. MOSTRA A CONFIRMAÇÃO (A ETAPA MAIS IMPORTANTE!)
      bool? confirmed = await _showRestoreConfirmation(context);
      if (confirmed != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restauração cancelada.')),
        );
        return;
      }

      // 5. SE CONFIRMADO, EXECUTA A RESTAURAÇÃO
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurando... NÃO FECHE O APP!')),
      );
      await _performRestore(backupData);

      // 6. SUCESSO
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await _showRestoreSuccess(context);
    } catch (e) {
      // 7. ERRO
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao restaurar: ${e.toString()}')),
      );
    }
  }

  /// Mostra um diálogo de confirmação destrutiva.
  static Future<bool?> _showRestoreConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ATENÇÃO! AÇÃO IRREVERSÍVEL!'),
        content: const Text(
            'Restaurar um backup irá APAGAR TODOS os dados atuais do aplicativo.\n\nEsta ação não pode ser desfeita.\n\nDeseja continuar?'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, Apagar e Restaurar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// Mostra um diálogo de sucesso pós-restauração.
  static Future<void> _showRestoreSuccess(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restauração Concluída'),
        content: const Text(
            'Os dados do backup foram importados com sucesso. É altamente recomendado fechar e reabrir o aplicativo agora.'),
        actions: [
          FilledButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  /// (Função _extractJsonFromPdf removida, pois não é mais necessária)

  /// Função interna que APAGA TUDO e preenche com o backup
  static Future<void> _performRestore(Map<String, dynamic> backupData) async {
    // 1. Limpa todas as boxes
    for (String boxName in _allBoxNames) {
      try {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox<dynamic>(boxName);
        }
        await Hive.box<dynamic>(boxName).clear();
      } catch (e) {
        // Ignora boxes que não existem no backup ou falham ao abrir
        // print('Aviso: Não foi possível limpar a box $boxName. $e');
      }
    }

    // 2. Preenche as boxes com os dados do backup
    for (String boxName in _allBoxNames) {
      if (backupData.containsKey(boxName)) {
        try {
          final box = Hive.box<dynamic>(boxName);
          final dataToRestore = backupData[boxName] as Map;

          // Converte o Map<dynamic, dynamic> do JSON para Map<String, dynamic>
          final Map<String, dynamic> safeData =
              Map<String, dynamic>.from(dataToRestore);

          // putAll é a forma mais rápida de inserir múltiplos
          await box.putAll(safeData);
        } catch (e) {
          // print('Erro ao restaurar dados para a box $boxName: $e');
          // Continua mesmo se uma box falhar
        }
      }
    }
  }
}
