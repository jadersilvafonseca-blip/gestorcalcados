// lib/pages/tickets_page.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:gestor_calcados_new/services/hive_service.dart';
import 'package:gestor_calcados_new/models/ticket.dart';
// Importa a nova página para ver detalhes/editar
import 'package:gestor_calcados_new/pages/ticket_details_page.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas Salvas')),
      body: ValueListenableBuilder<Box>(
        valueListenable: HiveService.listenable()!,
        builder: (context, box, _) {
          // A lista de tickets é buscada aqui
          final items = HiveService.getAllTickets();

          if (items.isEmpty) {
            return const Center(child: Text('Nenhuma ficha salva.'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final t = items[i];
              return ListTile(
                title: Text('Ficha ${t.id} • ${t.modelo} ${t.cor}'),
                subtitle: Text('Marca: ${t.marca} • Pares: ${t.pairs}'),

                // MUDANÇA PRINCIPAL: Torna o tile clicável
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // Navega para a nova tela, passando o ticket
                      builder: (context) => TicketDetailsPage(ticket: t),
                    ),
                  );
                },

                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    // Confirmação de exclusão é uma boa prática
                    _confirmDelete(context, t);
                  },
                ),
              );
            },
          );
        },
      ),
      // =========== ALTERAÇÃO ===========
      // O bottomNavigationBar foi completamente removido
      // =================================
    );
  }

  // Novo: Lógica de confirmação para excluir individualmente
  void _confirmDelete(BuildContext context, Ticket ticket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Ficha?'),
        content: Text(
            'Tem certeza que deseja excluir a ficha ${ticket.id} (${ticket.modelo})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              HiveService.deleteById(ticket.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Ficha ${ticket.id} excluída com sucesso.')),
              );
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =========== ALTERAÇÃO ===========
  // O método _confirmClearAll foi completamente removido
  // =================================
}
