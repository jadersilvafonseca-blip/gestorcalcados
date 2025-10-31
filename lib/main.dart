// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // <-- 1. IMPORT ADICIONADO

// Páginas
import 'pages/dashboard_page.dart';
import 'pages/create_ticket_page.dart';

// Hive + Repositórios
import 'services/hive_service.dart';
import 'data/adapters.dart';
import 'data/stats_repository.dart';

// Gerenciador de produção
import 'services/production_manager.dart';

// Constantes de boxes
const String kMovementsBox = 'movements_box';
const String kSectorDailyBox = 'sector_daily';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa o Hive para Flutter
  await Hive.initFlutter();

  // 2. Registra TODOS os adapters gerados
  await registerHiveAdapters();

  // 3. Inicializa os serviços e repositórios
  await HiveService.init();
  await StatsRepository().init();

  // 4. Inicializa o ProductionManager com as boxes já abertas
  final movementsBox = await Hive.openBox<dynamic>(kMovementsBox);
  final dailyBox = await Hive.openBox<dynamic>(kSectorDailyBox);

  // 2. CORREÇÃO: Usando a instância singleton .instance
  await ProductionManager.instance.initHiveBoxes(
    eventsBox: movementsBox,
    countersBox: dailyBox,
  );

  // 5. Roda o app
  runApp(const MyApp());
}

class Routes {
  static const dashboard = '/';
  static const createTicket = '/create-ticket';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor Calçados',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF223147),
      ),

      // --- 3. ADIÇÃO: Configuração de Localização (pt-BR) ---
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      // ---------------------------------------------------

      initialRoute: Routes.dashboard,
      routes: {
        Routes.dashboard: (_) => const DashboardPage(),
        Routes.createTicket: (_) => const CreateTicketPage(),
      },
    );
  }
}
