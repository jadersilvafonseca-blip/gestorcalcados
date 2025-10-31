// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _userController = TextEditingController();
  final _passController = TextEditingController();

  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    // ativa autovalidação após a 1ª tentativa
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) {
      // coloca o foco no primeiro campo inválido
      if ((_userController.text).trim().isEmpty) {
        _userFocus.requestFocus();
      } else {
        _passFocus.requestFocus();
      }
      return;
    }

    // fecha o teclado
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      // ==========================================
      // SIMULA AUTENTICAÇÃO (troque por FirebaseAuth se quiser)
      await Future.delayed(const Duration(milliseconds: 600));

      // // Exemplo com FirebaseAuth:
      // final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      //   email: _userController.text.trim(),
      //   password: _passController.text,
      // );
      // print('Logado: ${cred.user?.uid}');
      // ==========================================

      if (!mounted) return;
      // Navega para o Dashboard e remove o Login da pilha
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao entrar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateUser(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Informe o usuário ou e-mail';
    // Regras simples: se contém @, valida como e-mail (opcional)
    if (value.contains('@')) {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(value)) return 'E-mail inválido';
    }
    return null;
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 4) return 'Use ao menos 4 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(), // fecha teclado ao tocar fora
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Gestor de Calçados',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Faça login para continuar',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Usuário / E-mail
                      TextFormField(
                        controller: _userController,
                        focusNode: _userFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Usuário ou e-mail',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: _validateUser,
                        onFieldSubmitted: (_) => _passFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),

                      // Senha
                      TextFormField(
                        controller: _passController,
                        focusNode: _passFocus,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip:
                                _obscure ? 'Mostrar senha' : 'Ocultar senha',
                          ),
                        ),
                        validator: _validatePass,
                        onFieldSubmitted: (_) => _isLoading ? null : _doLogin(),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _doLogin,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: Text(_isLoading ? 'Entrando...' : 'Entrar'),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Versão 0.1 • protótipo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
