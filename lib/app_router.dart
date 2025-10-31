// lib/app_router.dart
import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/create_ticket_page.dart';
import 'pages/scanner_page.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case '/create-ticket':
        return MaterialPageRoute(builder: (_) => const CreateTicketPage());
      case '/scan':
        final args = (settings.arguments as Map?) ?? const {};
        final sectorId = (args['sectorId'] as String?) ?? 'corte';
        return MaterialPageRoute(
            builder: (_) => ScannerPage(sectorId: sectorId));
    }
    return null;
  }
}
