import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// --- NOSSOS IMPORTS DO FIREBASE ---
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart'; // O modelo que criámos
import 'package:uuid/uuid.dart'; // Para gerar o ID da equipa

// Removido DashboardPage, pois o AuthWrapper trata disso
// import '../pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _isLoading = false;
  bool _submitted = false;

  // --- Controladores para o formulário de cadastro ---
  final _regFormKey = GlobalKey<FormState>();
  final _regEmailController = TextEditingController();
  final _regSenhaController = TextEditingController();
  // --- ADICIONADO: Controlador para o Código da Equipa ---
  final _regTeamCodeController = TextEditingController();
  bool _regObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();

    _regEmailController.dispose();
    _regSenhaController.dispose();
    _regTeamCodeController.dispose(); // <-- Limpa o novo controlador
    super.dispose();
  }

  /// MUDANÇA: Função de Login agora verifica com FIREBASE
  Future<void> _doLogin() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      if ((_emailController.text).trim().isEmpty) {
        _emailFocus.requestFocus();
      } else {
        _passFocus.requestFocus();
      }
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // Tenta fazer login com Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text,
      );

      // SUCESSO: O AuthWrapperPage vai detetar a mudança e navegar
      // para o Dashboard automaticamente. Não precisamos fazer nada aqui.
    } on FirebaseAuthException catch (e) {
      // Trata erros específicos do Firebase
      String message;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'E-mail ou senha inválidos.';
      } else if (e.code == 'invalid-email') {
        message = 'O e-mail informado é inválido.';
      } else {
        message = 'Ocorreu um erro. Tente novamente.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Erro genérico
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorreu um erro inesperado.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Mostra o formulário de cadastro de novo usuário
  void _showRegisterSheet() {
    _regEmailController.clear();
    _regSenhaController.clear();
    _regTeamCodeController.clear(); // <-- Limpa o campo do código
    _regObscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Form(
                key: _regFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Novo Cadastro',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _regEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _validateEmail, // Reusa o validador
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _regSenhaController,
                        obscureText: _regObscure,
                        decoration: InputDecoration(
                          labelText: 'Senha (mín. 6 caracteres)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setModalState(() => _regObscure = !_regObscure),
                            icon: Icon(
                              _regObscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: _validatePass, // Reusa o validador
                      ),
                      const SizedBox(height: 14),
                      // --- CAMPO NOVO: CÓDIGO DA EQUIPA ---
                      TextFormField(
                        controller: _regTeamCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Código da Equipa (Opcional)',
                          hintText: 'Se você foi convidado, cole aqui',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group_add_outlined),
                        ),
                        // Este campo é opcional, sem validador
                      ),
                      // --- FIM DO CAMPO NOVO ---
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _doRegister, // Chama a nova função
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Salvar Cadastro'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// MUDANÇA: Lógica de salvar o cadastro com FIREBASE E FIRESTORE
  void _doRegister() async {
    if (!_regFormKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    // Mostra o loading no botão (opcional, mas bom)
    setState(() => _isLoading = true);

    try {
      // 1. Tenta criar o usuário no Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _regEmailController.text.trim(),
        password: _regSenhaController.text,
      );

      final newUser = userCredential.user;
      if (newUser == null) {
        throw Exception(
            'Erro ao criar usuário, Firebase não retornou o utilizador.');
      }

      // 2. Preparar o perfil do usuário para o Firestore
      final String teamCodeInput = _regTeamCodeController.text.trim();
      String teamId;
      UserRole role;
      List<String> allowedSectors = []; // Vazio por defeito

      // Se o campo de código está VAZIO, ele é um novo GESTOR
      if (teamCodeInput.isEmpty) {
        role = UserRole.gestor;
        teamId = const Uuid().v4(); // Gera um ID de equipa novo e único
      }
      // Se o campo de código está PREENCHIDO, ele é um PARTICIPANTE
      else {
        // Precisamos validar o código da equipa no Firestore
        final teamQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('teamId', isEqualTo: teamCodeInput)
            .where('role', isEqualTo: UserRole.gestor.name)
            .limit(1)
            .get();

        if (teamQuery.docs.isEmpty) {
          // Se não achou um gestor com esse teamId, o código é inválido
          throw FirebaseAuthException(code: 'team-code-invalid');
        }

        // Se o código é válido, ele é um participante
        role = UserRole.participante;
        teamId = teamCodeInput;
        // O Gestor irá definir os setores mais tarde
      }

      // 3. Criar o objeto AppUserModel
      final appUser = AppUserModel(
        uid: newUser.uid,
        email: newUser.email!,
        role: role,
        teamId: teamId,
        allowedSectors: allowedSectors,
        permissions: {},
      );

      // 4. Salvar o perfil no Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set(appUser.toFirestore());

      // 5. Sucesso
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o modal

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro realizado com sucesso!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'A senha é muito fraca (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está em uso.';
      } else if (e.code == 'invalid-email') {
        message = 'O e-mail informado é inválido.';
      } else if (e.code == 'team-code-invalid') {
        message =
            'Código de Equipa inválido! Não encontramos um gestor com esse código.';
      } else {
        message = 'Ocorreu um erro ao cadastrar.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro inesperado: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Para o loading
      setState(() => _isLoading = false);
    }
  }

  // Validador de E-mail
  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Informe o e-mail';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'E-mail inválido';
    }
    return null;
  }

  // Validador de Senha (mínimo 6)
  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 6) return 'A senha deve ter no mínimo 6 caracteres';
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
                      Icon(
                        Icons.show_chart_rounded, // Ícone de gestão
                        size: 50,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A sua produção na palma da mão', // Nova frase
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
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
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: _validateEmail,
                        onFieldSubmitted: (_) => _passFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
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
                        validator: _validatePass, // Valida 6+ caracteres
                        onFieldSubmitted: (_) => _isLoading ? null : _doLogin(),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _doLogin,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label:
                                  Text(_isLoading ? 'Entrando...' : 'Entrar'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _isLoading ? null : _showRegisterSheet,
                              child: const Text('Não tem conta? Cadastrar'),
                            ),
                          ),
                        ],
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
