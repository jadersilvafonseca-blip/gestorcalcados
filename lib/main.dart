import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import hive_flutter

// Páginas
import 'pages/dashboard_page.dart';
import 'pages/create_ticket_page.dart';

// Hive + Repositórios
import 'services/hive_service.dart';
import 'data/adapters.dart'; // <= caminho correto
import 'data/stats_repository.dart'; // <= usamos só este repo no bootstrap

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa o Hive para Flutter (chamada principal)
  await Hive.initFlutter();

  // 2. Registra TODOS os adapters gerados
  await registerHiveAdapters();

  // 3. Inicializa os serviços/repositórios que abrem Boxes específicos
  // (HiveService.init() agora só abre 'tickets_box', não chama initFlutter)
  await HiveService.init();
  // (StatsRepository().init() abre movements_box, sector_daily)
  await StatsRepository().init();

  runApp(const MyApp());
}

class Routes {
  static const dashboard = '/';
  static const createTicket = '/create-ticket';
  // Adicionar outras rotas aqui (login, signup, etc.) se necessário
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
      initialRoute: Routes
          .dashboard, // Mantenha ou mude para Routes.login se implementar login
      routes: {
        Routes.dashboard: (_) => const DashboardPage(),
        Routes.createTicket: (_) => const CreateTicketPage(),
        // Adicionar outras rotas aqui
      },
    );
  }
}
