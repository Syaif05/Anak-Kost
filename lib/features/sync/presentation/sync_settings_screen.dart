import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/models/sync_models.dart';
import '../../../core/sync/sync_providers.dart';
import 'conflict_resolution_screen.dart';

/// Layar Pengaturan Sinkronisasi Akun, Supabase & Cadangan Data (PRD GAMINI.md Bagian 5.2 & Bagian 7.5)
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final syncSummaryAsync = ref.watch(syncSummaryNotifierProvider);
    final supabaseSync = ref.watch(supabaseSyncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinkronisasi & Cadangan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Kartu Status Akun & Perangkat
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        supabaseSync.isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                        color: supabaseSync.isAuthenticated ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supabaseSync.isAuthenticated ? 'Terhubung ke Supabase' : 'Mode Offline Lokal',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              supabaseSync.isAuthenticated
                                  ? (supabaseSync.currentUserId ?? 'Akun Pemilik Kost')
                                  : 'Belum ada sesi cloud aktif',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Platform:', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      const Text('Samsung Galaxy S24+ (Android)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target Sinkronisasi:', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      const Text('MacBook Air M2 (macOS)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Kartu Status Sinkronisasi Real-Time
          syncSummaryAsync.when(
            data: (summary) => _buildSyncStatusCard(context, summary),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, _) => Card(
              color: Colors.red.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gagal memeriksa status sync: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Kartu Ekspor CSV & Cadangan Terenkripsi
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ekspor & Cadangan Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Seluruh data keuangan dan inventaris dapat diekspor ke CSV (dengan proteksi formula injection) atau dicadangkan dalam format terenkripsi.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Tombol Ekspor Transaksi CSV
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.table_chart, color: Colors.white, size: 20),
                    ),
                    title: const Text('Ekspor Transaksi Keuangan (CSV)'),
                    subtitle: const Text('Format spreadsheet terlindungi formula injection'),
                    trailing: const Icon(Icons.download),
                    onTap: _isExporting ? null : _handleExportTransactionsCsv,
                  ),
                  const Divider(),

                  // Tombol Ekspor Inventaris CSV
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.inventory_2, color: Colors.white, size: 20),
                    ),
                    title: const Text('Ekspor Inventaris Barang (CSV)'),
                    subtitle: const Text('Daftar barang beserta unit dan sisa stok'),
                    trailing: const Icon(Icons.download),
                    onTap: _isExporting ? null : _handleExportInventoryCsv,
                  ),
                  const Divider(),

                  // Tombol Backup Terenkripsi
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.security, color: Colors.white, size: 20),
                    ),
                    title: const Text('Buat Cadangan Terenkripsi (.anakkostbackup)'),
                    subtitle: const Text('Arsip terenkripsi AES-256-GCM dengan passphrase pemulihan'),
                    trailing: const Icon(Icons.lock),
                    onTap: _isExporting ? null : _handleCreateEncryptedBackup,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, SyncSummary summary) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final lastSyncText = summary.lastSyncTime != null ? dateFormat.format(summary.lastSyncTime!) : 'Belum pernah';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStateIcon(summary.state),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.state.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Sinkronisasi terakhir: $lastSyncText', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Indikator Pending & Konflik
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('${summary.pendingOutboxCount}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Antrean Outbox', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: summary.conflictCount > 0
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ConflictResolutionScreen()),
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: summary.conflictCount > 0 ? Colors.orange.withAlpha(30) : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: summary.conflictCount > 0 ? Border.all(color: Colors.orange) : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${summary.conflictCount}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: summary.conflictCount > 0 ? Colors.orange.shade800 : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary.conflictCount > 0 ? 'Konflik (Klik Tinjau)' : 'Konflik',
                            style: TextStyle(
                              fontSize: 12,
                              color: summary.conflictCount > 0 ? Colors.orange.shade800 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tombol Sinkronkan Sekarang
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(syncSummaryNotifierProvider.notifier).triggerSync();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sinkronkan Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateIcon(SyncState state) {
    switch (state) {
      case SyncState.idle:
      case SyncState.success:
        return const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white));
      case SyncState.syncing:
        return const CircleAvatar(backgroundColor: Colors.blue, child: CircularProgressIndicator(color: Colors.white));
      case SyncState.conflict:
        return const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.priority_high, color: Colors.white));
      case SyncState.error:
        return const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.error_outline, color: Colors.white));
      case SyncState.offline:
        return const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.cloud_off, color: Colors.white));
    }
  }

  Future<void> _handleExportTransactionsCsv() async {
    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(backupAndExportServiceProvider);
      final csv = await exportService.exportTransactionsCsv();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ekspor Transaksi Berhasil'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Berikut cuplikan CSV yang dihasilkan (aman dari formula injection):', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(csv.length > 500 ? '${csv.substring(0, 500)}...' : csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExportInventoryCsv() async {
    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(backupAndExportServiceProvider);
      final csv = await exportService.exportInventoryCsv();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ekspor Inventaris Berhasil'),
            content: SingleChildScrollView(
              child: Text(csv.length > 500 ? '${csv.substring(0, 500)}...' : csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleCreateEncryptedBackup() async {
    final secretController = TextEditingController(text: 'anak-kost-recovery-key-2026');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cadangkan Data Terenkripsi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan passphrase atau recovery secret untuk mengunci arsip backup (AES-256-GCM):', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: secretController,
              decoration: const InputDecoration(labelText: 'Recovery Secret / Passphrase', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Buat Cadangan')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(backupAndExportServiceProvider);
      final backupEnvelope = await exportService.createEncryptedBackup(recoverySecret: secretController.text.trim());

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cadangan Terenkripsi Berhasil Dibuat'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arsip .anakkostbackup telah dibuat secara aman menggunakan enkripsi AES-256-GCM.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Text('Format: ${backupEnvelope['format']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Ukuran Ciphertext: ${(backupEnvelope['ciphertext_base64'] as String).length} karakter base64', style: const TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
