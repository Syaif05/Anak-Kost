import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/core_providers.dart';
import '../../domain/models/document_models.dart';
import '../providers/documents_providers.dart';

class AddDocumentDialog extends ConsumerStatefulWidget {
  final Uint8List masterKey;

  const AddDocumentDialog({super.key, required this.masterKey});

  @override
  ConsumerState<AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends ConsumerState<AddDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _docNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  String _documentType = 'ktp';
  DateTime? _expiryDate;
  bool _isLoading = false;

  Uint8List? _pickedFileBytes;
  String? _pickedFileName;
  String? _pickedMimeType;

  final Map<String, String> _typeLabels = {
    'ktp': 'KTP (Identitas)',
    'ktm': 'KTM / Kartu Mahasiswa',
    'internship_letter': 'Surat Penerimaan Magang',
    'lease_contract': 'Kontrak Sewa Kost',
    'other': 'Dokumen Lain',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _docNumberController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _pickPhoto(bool fromCamera) async {
    try {
      final imageService = ref.read(imagePipelineServiceProvider);
      final result = fromCamera
          ? await imageService.captureImageFromCamera()
          : await imageService.pickImageFromGallery();

      if (result != null) {
        setState(() {
          _pickedFileBytes = result.bytes;
          _pickedFileName = result.fileName;
          _pickedMimeType = result.mimeType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(documentsRepositoryProvider);
      final expiryStr = _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null;

      final tags = _tagsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final metadata = DocumentMetadata(
        title: _titleController.text.trim(),
        documentNumber: _docNumberController.text.trim().isEmpty ? null : _docNumberController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        tags: tags,
        expiryDate: expiryStr,
      );

      await repo.createEncryptedDocument(
        documentType: _documentType,
        metadata: metadata,
        masterKey: widget.masterKey,
        expiresOn: expiryStr,
        fileBytes: _pickedFileBytes,
        mimeType: _pickedMimeType,
        mediaKind: 'photo',
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumen & berkas berhasil dienkripsi ke brankas!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Simpan ke Brankas',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _documentType,
                    decoration: InputDecoration(
                      labelText: 'Jenis Dokumen',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _typeLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (val) => setState(() => _documentType = val ?? _documentType),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Judul Dokumen *',
                      hintText: 'Misal: KTP Pribadi, KTM ITB, Kontrak Kost',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Judul wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _docNumberController,
                    decoration: InputDecoration(
                      labelText: 'Nomor Dokumen (Sensitif & Dienkripsi)',
                      hintText: 'Misal: NIK KTP / NIM Kampus',
                      prefixIcon: const Icon(Icons.password_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _expiryDate != null
                          ? 'Masa Berlaku: ${DateFormat('dd MMM yyyy').format(_expiryDate!)}'
                          : 'Set Masa Berlaku (Opsional)',
                    ),
                    onPressed: _pickExpiryDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tagsController,
                    decoration: InputDecoration(
                      labelText: 'Tag (Pisahkan dengan koma)',
                      hintText: 'Misal: identitas, magang, kampus',
                      prefixIcon: const Icon(Icons.tag),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Rahasia (Dienkripsi)',
                      prefixIcon: const Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section Lampiran Berkas / Foto
                  if (_pickedFileBytes == null) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Lampirkan Foto / Berkas (AES-256)'),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_camera),
                                  title: const Text('Ambil dari Kamera'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _pickPhoto(true);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Pilih dari Galeri (Photo Picker)'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _pickPhoto(false);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield, color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickedFileName ?? 'Lampiran Dokumen',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${(_pickedFileBytes!.length / 1024).toStringAsFixed(1)} KB • Siap Dienkripsi AES-256',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _pickedFileBytes = null;
                                _pickedFileName = null;
                                _pickedMimeType = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Enkripsi & Simpan Dokumen', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
