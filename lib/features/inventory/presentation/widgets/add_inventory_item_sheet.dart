import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/inventory_models.dart';
import '../providers/inventory_providers.dart';

class AddInventoryItemSheet extends ConsumerStatefulWidget {
  const AddInventoryItemSheet({super.key});

  @override
  ConsumerState<AddInventoryItemSheet> createState() => _AddInventoryItemSheetState();
}

class _AddInventoryItemSheetState extends ConsumerState<AddInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialQtyController = TextEditingController(text: '0');
  final _minQtyController = TextEditingController(text: '0');
  final _locationController = TextEditingController();

  String _selectedCategory = 'Makanan Pokok';
  String _baseUnit = 'pcs'; // pcs, g, ml
  bool _isLoading = false;

  final List<String> _categories = [
    'Makanan Pokok',
    'Bahan Masak',
    'Kebersihan',
    'Kebutuhan Mandi',
    'Obat & P3K',
    'Lainnya',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _initialQtyController.dispose();
    _minQtyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final initialQty = double.tryParse(_initialQtyController.text.replaceAll(',', '.')) ?? 0;
    final minQty = double.tryParse(_minQtyController.text.replaceAll(',', '.')) ?? 0;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);

      await repo.createItem(
        name: _nameController.text.trim(),
        stockCategory: _selectedCategory,
        baseUnit: _baseUnit,
        initialQtyMilli: StockUnit.toMilli(initialQty),
        minimumQtyMilli: StockUnit.toMilli(minQty),
        locationLabel: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang inventaris berhasil ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
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
                    'Tambah Barang Kebutuhan',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Barang *',
                  hintText: 'Misal: Beras Ramos, Sabun Mandi, Minyak Goreng',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama barang wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategori Kebutuhan',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val ?? _selectedCategory),
              ),
              const SizedBox(height: 12),
              const Text('Satuan Dasar Barang:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pcs', label: Text('Pcs / Buah')),
                  ButtonSegment(value: 'g', label: Text('Gram (g)')),
                  ButtonSegment(value: 'ml', label: Text('Mililiter (ml)')),
                ],
                selected: {_baseUnit},
                onSelectionChanged: (val) => setState(() => _baseUnit = val.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _initialQtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Stok Awal ($_baseUnit)',
                        prefixIcon: const Icon(Icons.add_shopping_cart),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minQtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Ambang Minimum ($_baseUnit)',
                        prefixIcon: const Icon(Icons.warning_amber),
                        helperText: 'Pemicu pengingat belanja',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Lokasi Simpan (Opsional)',
                  hintText: 'Misal: Lemari Dapur, Kamar Mandi, Bawah Kasur',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
