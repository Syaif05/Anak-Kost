import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/models/sync_models.dart';
import '../../../core/sync/sync_providers.dart';

/// Layar Resolusi Konflik Sinkronisasi (PRD GAMINI.md Bagian 7.5.5)
/// Menampilkan perbandingan sisi-ke-sisi antara versi lokal perangkat dan versi server
class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  ConsumerState<ConflictResolutionScreen> createState() => _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends ConsumerState<ConflictResolutionScreen> {
  late Future<List<SyncConflictData>> _conflictsFuture;

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  void _loadConflicts() {
    final resolver = ref.read(conflictResolverProvider);
    _conflictsFuture = resolver.getPendingConflicts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolusi Konflik Data'),
      ),
      body: FutureBuilder<List<SyncConflictData>>(
        future: _conflictsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat konflik: ${snapshot.error}'));
          }

          final conflicts = snapshot.data ?? [];
          if (conflicts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  const Text('Tidak ada konflik data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Semua data perangkat dan server sinkron sempurna.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return _buildConflictCard(context, conflict);
            },
          );
        },
      ),
    );
  }

  Widget _buildConflictCard(BuildContext context, SyncConflictData conflict) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Konflik: ${conflict.aggregateType.toUpperCase()} (${conflict.aggregateId.substring(0, minLength(conflict.aggregateId, 8))}...)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text('Server Rev: ${conflict.remoteVersion}', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Perubahan dibuat di dua perangkat saat offline. Pilih versi mana yang ingin Anda pertahankan:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Perbandingan sisi-ke-sisi
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Versi Lokal (Perangkat Ini)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                        const SizedBox(height: 8),
                        Text(
                          const JsonEncoder.withIndent('  ').convert(conflict.localSnapshot),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Versi Server (Perangkat Lain)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                        const SizedBox(height: 8),
                        Text(
                          const JsonEncoder.withIndent('  ').convert(conflict.remoteSnapshot),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tombol Resolusi
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolveWithServer(conflict.operationId),
                    child: const Text('Gunakan Versi Server'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _resolveWithLocal(conflict.operationId, conflict.remoteVersion),
                    child: const Text('Gunakan Versi Lokal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int minLength(String str, int len) => str.length < len ? str.length : len;

  Future<void> _resolveWithLocal(String opId, int remoteVer) async {
    final resolver = ref.read(conflictResolverProvider);
    await resolver.resolveWithLocal(opId, remoteVer);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Versi lokal dipertahankan. Akan dikirim ulang pada sinkronisasi berikutnya.')),
      );
      setState(() => _loadConflicts());
    }
  }

  Future<void> _resolveWithServer(String opId) async {
    final resolver = ref.read(conflictResolverProvider);
    await resolver.resolveWithRemote(opId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Versi server diterima. Intent lokal dibatalkan.')),
      );
      setState(() => _loadConflicts());
    }
  }
}
