import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestor_calcados_new/models/app_user_model.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _teamIdCtrl = TextEditingController(); // Para o código da equipe

  UserRole _role = UserRole.participante; // Começa como participante
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. Criar o usuário no Firebase Auth (Email/Senha)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw Exception("Usuário não foi criado.");
      }

      String teamId;
      Map<String, bool> permissions;

      // 2. Lógica para definir o teamId e as Permissões
      if (_role == UserRole.gestor) {
        // --- É UM GESTOR (NOVA FÁBRICA) ---
        // Cria um novo documento de time para gerar um ID único
        teamId = FirebaseFirestore.instance.collection('teams').doc().id;
        // Gestor tem todas as permissões
        permissions = AppPermissions.defaultGestorPermissions;

        // (Opcional) Salva o documento do time
        await FirebaseFirestore.instance.collection('teams').doc(teamId).set({
          'ownerUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'factoryName': '${_emailCtrl.text.trim()}\'s Factory', // Nome Padrão
        });
      } else {
        // --- É UM PARTICIPANTE (ENTRANDO EM UMA FÁBRICA) ---
        teamId = _teamIdCtrl.text.trim();
        if (teamId.isEmpty) {
          throw Exception("O código da equipe é obrigatório.");
        }
        // (Em produção, você validaria se este teamId existe)

        // Participante começa sem nenhuma permissão
        permissions = AppPermissions.defaultParticipantPermissions;
      }

      // 3. Criar o *documento do perfil* no Firestore (Coleção 'users')
      final newUserModel = AppUserModel(
        uid: user.uid,
        email: user.email!,
        teamId: teamId,
        role: _role,
        permissions: permissions,
        allowedSectors: [], // Começa sem setores
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(newUserModel.toFirestore());

      // 4. Sucesso - Volta para o AuthWrapper (que vai logar)
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Erro de autenticação.");
    } catch (e) {
      _showError(e.toString());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Email obrigatório' : null,
              ),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (v) =>
                    v!.length < 6 ? 'Senha muito curta (mín. 6)' : null,
              ),
              const SizedBox(height: 20),
              // --- O Seletor de Função (Gestor / Participante) ---
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                      value: UserRole.participante,
                      label: Text('Sou Participante'),
                      icon: Icon(Icons.person)),
                  ButtonSegment(
                      value: UserRole.gestor,
                      label: Text('Sou Gestor'),
                      icon: Icon(Icons.factory)),
                ],
                selected: {_role},
                onSelectionChanged: (newRole) {
                  setState(() => _role = newRole.first);
                },
              ),
              const SizedBox(height: 20),

              // --- Campo que aparece se for "Participante" ---
              if (_role == UserRole.participante)
                TextFormField(
                  controller: _teamIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código da Equipe (do seu Gestor)',
                  ),
                  validator: (v) =>
                      (_role == UserRole.participante && v!.isEmpty)
                          ? 'Código obrigatório'
                          : null,
                ),

              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: _register,
                  child: const Text('Criar Conta'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
