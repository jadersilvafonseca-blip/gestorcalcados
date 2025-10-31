// lib/data/mock_repository.dart
import 'package:gestor_calcados_new/models/ticket.dart';

final mockTickets = <Ticket>[
  Ticket(
      id: 'T001',
      cliente: 'ACME',
      modelo: 'XYZ',
      marca: 'Nike',
      cor: 'Branco',
      pairs: 12,
      grade: const {},
      observacao: '',
      pedido: ''),
  Ticket(
      id: 'T002',
      cliente: 'Foo',
      modelo: 'RUN',
      marca: 'Adidas',
      cor: 'Preto',
      pairs: 8,
      grade: const {},
      observacao: '',
      pedido: ''),
];
