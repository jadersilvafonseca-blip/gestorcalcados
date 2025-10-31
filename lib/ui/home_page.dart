import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestor de Calçados")),
      body: const Center(
        child: Text(
          "Bem-vindo ao Gestor de Calçados 🚀",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
