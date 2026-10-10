import 'package:flutter/material.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan & Budget'),
      ),
      body: const Center(
        child: Text('Modul Keuangan (Fase 2)'),
      ),
    );
  }
}
