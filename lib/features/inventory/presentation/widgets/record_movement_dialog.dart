import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/inventory_models.dart';
import '../providers/inventory_providers.dart';

class RecordMovementDialog extends ConsumerStatefulWidget {
  final InventoryItemWithStock itemWithStock;
  final String initialMovementType; // 'use' or 'add'

  const RecordMovementDialog({
    super.key,
    required this.itemWithStock,
    this.initialMovementType = 'use',
  });

  @override
  ConsumerState<RecordMovementDialog> createState() => _RecordMovementDialogState();
}

class _RecordMovementDialogState extends ConsumerState<RecordMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  late String _movementType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _movementType = widget.initialMovementType;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawQty = double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 0;
    if (rawQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah harus lebih dari 0')),
      );
      return;
    }

    final qtyMilli = StockUnit.toMilli(rawQty);

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);

      await repo.recordMovement(
        itemId: widget.itemWithStock.item.id,
        movementType: _movementType,
        quantityDeltaMilli: _movementType == 'use' ? -qtyMilli : qtyMilli,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _movementType == 'use'
                  ? 'Stok ${widget.itemWithStock.item.name} berhasil digunakan'
                  : 'Stok ${widget.itemWithStock.item.name} berhasil ditambahkan',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Gagal: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.itemWithStock;
    final isUse = _movementType == 'use';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    Text(
                      isUse ? 'Pakai Stok' : 'Tambah Stok',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        'Sisa stok saat ini: ${item.formattedCurrentStock}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.isLowStock ? Colors.red : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'use', label: Text('Pakai Stok'), icon: Icon(Icons.remove_circle_outline)),
                    ButtonSegment(value: 'add', label: Text('Tambah Stok'), icon: Icon(Icons.add_circle_outline)),
                  ],
                  selected: {_movementType},
                  onSelectionChanged: (val) => setState(() => _movementType = val.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Jumlah (${item.item.baseUnit}) *',
                    hintText: 'Misal: 1 atau 500',
                    prefixIcon: const Icon(Icons.scale_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Jumlah wajib diisi';
                    final parsed = double.tryParse(val.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) return 'Masukkan angka valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: 'Alasan / Keterangan (Opsional)',
                    hintText: isUse ? 'Misal: Masak makan malam' : 'Misal: Belanja tambahan',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUse ? Colors.amber.shade800 : Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          isUse ? 'Konfirmasi Pemakaian' : 'Konfirmasi Penambahan',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
