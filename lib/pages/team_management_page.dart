import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar para o clipboard
import 'package:gestor_calcados_new/models/app_user_model.dart';
import 'package:gestor_calcados_new/models/sector_models.dart';
import 'package:gestor_calcados_new/services/production_manager.dart';

/// Página onde o Gestor pode ver seu código de equipe e gerenciar
/// as permissões dos participantes.
class TeamManagementPage extends StatefulWidget {
  final AppUserModel gestor;

  const TeamManagementPage({super.key, required this.gestor});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  // Referência à coleção de usuários no Firestore
  final _usersCollection = FirebaseFirestore.instance.collection('users');

  // --- MUDANÇA: Cache de setores (carregado 1 vez) ---
  List<ConfigurableSector> _allSectorsCache = [];
  bool _isLoadingSectors = true;
  // --- FIM DA MUDANÇA ---

  @override
  void initState() {
    super.initState();
    // --- MUDANÇA: Carrega os setores do time do gestor ---
    _loadSectors();
    // --- FIM DA MUDANÇA ---
  }

  // --- MUDANÇA: Nova função para carregar setores async ---
  Future<void> _loadSectors() async {
    setState(() => _isLoadingSectors = true);
    try {
      _allSectorsCache = await ProductionManager.instance
          .getAllSectorModels(widget.gestor.teamId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao carregar setores: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) {
      setState(() => _isLoadingSectors = false);
    }
  }
  // --- FIM DA MUDANÇA ---

  /// Mostra um diálogo para editar as permissões de um participante
  void _showEditPermissionsDialog(AppUserModel participante) {
    // --- MUDANÇA: Usa o cache de setores ---
    // final allSectors = ProductionManager.instance.getAllSectorModels(); // ANTIGO
    final allSectors = _allSectorsCache; // NOVO
    // --- FIM DA MUDANÇA ---

    final Set<String> tempAllowedSectors =
        Set<String>.from(participante.allowedSectors);
    final Map<String, bool> tempPermissions =
        Map<String, bool>.from(participante.permissions);

    final allPermissionKeys =
        AppPermissions.defaultParticipantPermissions.keys.toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Permissões de ${participante.email}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Seção 1 - Permissões Granulares ---
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Text(
                          'Permissões de Acesso',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...allPermissionKeys.map((key) {
                        final label = AppPermissions.getPermissionLabel(key);
                        final hasPermission = tempPermissions[key] ?? false;

                        return CheckboxListTile(
                          title: Text(label),
                          value: hasPermission,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              tempPermissions[key] = value ?? false;
                            });
                          },
                        );
                      }).toList(),

                      const Divider(height: 24),

                      // --- Seção 2 - Setores Permitidos ---
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Setores Permitidos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      // --- MUDANÇA: Mostra loading se os setores não carregaram ---
                      if (_isLoadingSectors)
                        const Center(child: CircularProgressIndicator())
                      else if (allSectors.isEmpty)
                        const Center(child: Text('Nenhum setor cadastrado.'))
                      else
                        ...allSectors.map((sector) {
                          final bool hasPermission =
                              tempAllowedSectors.contains(sector.firestoreId);

                          return CheckboxListTile(
                            title: Text(sector.label),
                            value: hasPermission,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempAllowedSectors.add(sector.firestoreId);
                                } else {
                                  tempAllowedSectors.remove(sector.firestoreId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      // --- FIM DA MUDANÇA ---
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await _usersCollection.doc(participante.uid).update({
                        'allowedSectors': tempAllowedSectors.toList(),
                        'permissions': tempPermissions,
                      });
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Permissões atualizadas!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao salvar: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Equipe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Card 1: Código da Equipe ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código da sua Equipe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Passe este código para novos participantes se cadastrarem na sua equipe.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      widget.gestor.teamId,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Código'),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.gestor.teamId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código copiado!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Lista de Participantes ---
            Text(
              'Participantes da Equipe',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
              stream: _usersCollection
                  .where('teamId', isEqualTo: widget.gestor.teamId)
                  .where('role', isEqualTo: UserRole.participante.name)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar participantes: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Nenhum participante encontrado. Compartilhe seu código de equipe para convidá-los.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final participantsDocs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: participantsDocs.length,
                  itemBuilder: (context, index) {
                    final doc = participantsDocs[index];
                    final participant = AppUserModel.fromFirestore(doc);

                    final int permCount = participant.permissions.values
                        .where((v) => v == true)
                        .length;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(participant.email),
                        subtitle: Text(
                            '${participant.allowedSectors.length} setores | $permCount permissões'),
                        trailing:
                            const Icon(Icons.edit_note_outlined, size: 28),
                        onTap: () {
                          // --- MUDANÇA: Verifica se os setores estão carregados ---
                          if (_isLoadingSectors) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Carregando setores... Tente novamente em alguns segundos.')));
                          } else {
                            _showEditPermissionsDialog(participant);
                          }
                          // --- FIM DA MUDANÇA ---
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- REMOVIDA: A extensão 'extension on Future...' não é mais necessária ---
// extension on Future<List<ConfigurableSector>> {
//   map(CheckboxListTile Function(dynamic sector) param0) {}
// }
