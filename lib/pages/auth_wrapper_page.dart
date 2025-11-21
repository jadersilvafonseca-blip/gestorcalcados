import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gestor_calcados_new/pages/dashboard_page.dart';
import 'package:gestor_calcados_new/pages/login_page.dart';

/// Esta página verifica o estado da autenticação (se o usuário está
/// logado ou não) e redireciona.
///
/// A LEITURA DO PERFIL DO USUÁRIO FOI MOVIDA PARA DENTRO DA DASHBOARDPAGE
/// PARA EVITAR O BUG "INTERNAL ASSERTION FAILED" DO FIRESTORE WEB.
class AuthWrapperPage extends StatelessWidget {
  const AuthWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder 1: "Ouve" as mudanças de LOGIN/LOGOUT (Firebase Auth)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. Se o app ainda está verificando...
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Se o snapshot TEM dados (usuário está logado no Auth)
        if (authSnapshot.hasData) {
          // SUCESSO! Vai direto para o Dashboard.
          // O Dashboard agora é responsável por buscar o perfil do usuário.
          return DashboardPage(); // <-- MUDANÇA: Não passamos mais o usuário
        }

        // 3. Se não tem dados no authSnapshot (usuário NÃO está logado)
        // Vai para a página de Login
        return LoginPage();
      },
    );
  }
}
