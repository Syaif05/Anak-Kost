import 'package:flutter/material.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kost: Tagihan & Dokumen'),
      ),
      body: const Center(
        child: Text('Modul Kost (Tagihan & Dokumen) (Fase 3 & 4)'),
      ),
    );
  }
}
