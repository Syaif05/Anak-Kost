import 'package:flutter/material.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebutuhan & Stok'),
      ),
      body: const Center(
        child: Text('Modul Kebutuhan & Stok (Fase 4)'),
      ),
    );
  }
}
