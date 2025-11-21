import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gestor_calcados_new/pages/auth_wrapper_page.dart';
import 'package:gestor_calcados_new/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gestor_calcados_new/services/production_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ CORREÇÃO 1: Capturar erros ANTES de inicializar Firebase
  if (kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔥 ERRO FLUTTER: ${details.exception}');
      debugPrint('📋 Stack: ${details.stack}');
    };
  }

  try {
    // ✅ CORREÇÃO 2: Inicializar Firebase PRIMEIRO
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ CORREÇÃO 3: Configurar Firestore DEPOIS do Firebase inicializado
    if (kDebugMode) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    // ✅ CORREÇÃO 4: Inicializar ProductionManager (opcional)
    await ProductionManager.instance.initFirebase();

    debugPrint('✅ Firebase inicializado com sucesso');
  } catch (e, stackTrace) {
    debugPrint('❌ ERRO ao inicializar Firebase: $e');
    debugPrint('Stack: $stackTrace');
  }

  // ✅ Roda o app
  runApp(const MyApp());
}

class Routes {
  static const login = '/';
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
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      initialRoute: Routes.login,
      routes: {
        Routes.login: (_) => const AuthWrapperPage(),
      },
    );
  }
}
