import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../domain/models/document_models.dart';
import '../providers/documents_providers.dart';
import 'add_document_dialog.dart';

class VaultView extends ConsumerStatefulWidget {
  const VaultView({super.key});

  @override
  ConsumerState<VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends ConsumerState<VaultView> {
  final _pinController = TextEditingController();
  final Set<String> _revealedDocIds = {}; // ID dokumen yang nomornya sedang ditampilkan
  bool _isVerifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlockVault() async {
    final lockService = ref.read(appLockServiceProvider);
    final keyMgr = ref.read(keyManagerProvider);

    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Autentikasi Brankas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan PIN 6-digit keamanan Anda untuk mendekripsi dokumen brankas:'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'PIN 6-Digit',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Buka'),
            ),
          ],
        );
      },
    );

    if (pin == null || pin.length != 6) return;

    setState(() => _isVerifying = true);

    try {
      final isPinValid = await lockService.unlockWithPin(pin);
      if (!isPinValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.red, content: Text('PIN salah! Akses brankas ditolak.')),
          );
        }
        return;
      }

      // Ambil atau buat master key lokal brankas
      var masterKey = await keyMgr.getLocalMasterKey('vault');
      if (masterKey == null) {
        masterKey = keyMgr.generateMasterKey();
        await keyMgr.saveLocalMasterKey('vault', masterKey);
      }

      ref.read(vaultMasterKeyProvider.notifier).setKey(masterKey);
      ref.read(vaultUnlockedProvider.notifier).setUnlocked(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brankas berhasil dibuka 🔓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka brankas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _lockVault() {
    ref.read(vaultMasterKeyProvider.notifier).setKey(null);
    ref.read(vaultUnlockedProvider.notifier).setUnlocked(false);
    setState(() {
      _revealedDocIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brankas dikunci kembali 🔒')),
    );
  }

  void _openAddDocument(Uint8List masterKey) {
    showDialog(
      context: context,
      builder: (_) => AddDocumentDialog(masterKey: masterKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = ref.watch(vaultUnlockedProvider);
    final masterKey = ref.watch(vaultMasterKeyProvider);

    if (!isUnlocked || masterKey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined, size: 72, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Brankas Dokumen Terkunci',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'KTP, KTM, surat kontrak, dan dokumen penting lainnya dienkripsi dengan AES-256-GCM. Autentikasi diperlukan untuk melihat isi dokumen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_open),
                label: _isVerifying
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Buka Kunci Brankas', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isVerifying ? null : _unlockVault,
              ),
            ],
          ),
        ),
      );
    }

    // Vault Unlocked State
    final documentsAsync = ref.watch(documentsStreamProvider(null));

    return Column(
      children: [
        // Top Security Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.green.withAlpha(25),
          child: Row(
            children: [
              const Icon(Icons.lock_open_rounded, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Brankas Aktif (AES-256-GCM Dekripsi)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('Kunci Brankas'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _lockVault,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List of Decrypted Documents
        Expanded(
          child: documentsAsync.when(
            data: (docs) {
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_special_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Dokumen di Brankas',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Simpan KTP, KTM, atau berkas penting dengan enkripsi aman',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Dokumen Pertama'),
                        onPressed: () => _openAddDocument(masterKey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final docWithDetails = docs[index];
                  return _EncryptedDocumentCard(
                    docWithDetails: docWithDetails,
                    masterKey: masterKey,
                    isNumberRevealed: _revealedDocIds.contains(docWithDetails.document.id),
                    onToggleReveal: () {
                      setState(() {
                        if (_revealedDocIds.contains(docWithDetails.document.id)) {
                          _revealedDocIds.remove(docWithDetails.document.id);
                        } else {
                          _revealedDocIds.add(docWithDetails.document.id);
                        }
                      });
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hapus Dokumen?'),
                          content: const Text('Dokumen akan dihapus dari brankas.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref.read(documentsRepositoryProvider).deleteDocument(docWithDetails.document.id);
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Gagal memuat dokumen: $err')),
          ),
        ),
      ],
    );
  }
}

class _EncryptedDocumentCard extends ConsumerWidget {
  final DocumentWithDetails docWithDetails;
  final Uint8List masterKey;
  final bool isNumberRevealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onDelete;

  const _EncryptedDocumentCard({
    required this.docWithDetails,
    required this.masterKey,
    required this.isNumberRevealed,
    required this.onToggleReveal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(documentsRepositoryProvider);

    return FutureBuilder<DocumentMetadata>(
      future: repo.decryptDocumentMetadata(
        document: docWithDetails.document,
        masterKey: masterKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.red.withAlpha(15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gagal mendekripsi: Kunci tidak cocok atau data korup (${snapshot.error})',
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        final meta = snapshot.data!;
        final isExpired = docWithDetails.isExpired;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(100)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Type badge & Delete button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        docWithDetails.typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (isExpired) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Kedaluwarsa', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  meta.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                // Sensitive Document Number (e.g. NIK)
                if (meta.documentNumber != null && meta.documentNumber!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.password, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isNumberRevealed
                                ? meta.documentNumber!
                                : '•••• •••• •••• ${meta.documentNumber!.length > 4 ? meta.documentNumber!.substring(meta.documentNumber!.length - 4) : ""}',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: Icon(isNumberRevealed ? Icons.visibility_off : Icons.visibility, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onToggleReveal,
                        ),
                      ],
                    ),
                  ),
                ],

                // Expiry Date
                if (meta.expiryDate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Berlaku hingga: ${meta.expiryDate}',
                    style: TextStyle(fontSize: 12, color: isExpired ? Colors.red : theme.colorScheme.outline),
                  ),
                ],

                // Notes
                if (meta.notes != null && meta.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meta.notes!,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],

                // Tags
                if (meta.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: meta.tags.map((t) {
                      return Chip(
                        label: Text(t, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
