import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/money.dart';
import '../../domain/models/inventory_models.dart';
import '../providers/inventory_providers.dart';

class AddShoppingItemSheet extends ConsumerStatefulWidget {
  final String? initialListId;

  const AddShoppingItemSheet({super.key, this.initialListId});

  @override
  ConsumerState<AddShoppingItemSheet> createState() => _AddShoppingItemSheetState();
}

class _AddShoppingItemSheetState extends ConsumerState<AddShoppingItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedListId;
  String? _selectedInventoryItemId;
  String _unit = 'pcs';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.initialListId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedListId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih daftar belanja')),
      );
      return;
    }

    final rawQty = double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 1;
    final price = _priceController.text.trim().isNotEmpty ? Money.parse(_priceController.text) : null;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);

      await repo.addShoppingListItem(
        shoppingListId: _selectedListId!,
        inventoryItemId: _selectedInventoryItemId,
        name: _nameController.text.trim(),
        requestedQtyMilli: StockUnit.toMilli(rawQty),
        unit: _unit,
        estimatedTotalRp: price,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item berhasil ditambahkan ke daftar belanja')),
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
    final listsAsync = ref.watch(shoppingListsStreamProvider);
    final itemsAsync = ref.watch(inventoryItemsStreamProvider(null));

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
                    'Tambah Barang Belanja',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              listsAsync.when(
                data: (lists) {
                  if (lists.isEmpty) {
                    return const Text('Belum ada daftar belanja. Buat daftar terlebih dahulu.');
                  }
                  _selectedListId ??= lists.first.list.id;
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedListId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Daftar Belanja *',
                      prefixIcon: const Icon(Icons.list_alt),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: lists.map((l) {
                      return DropdownMenuItem(value: l.list.id, child: Text(l.list.name));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedListId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              itemsAsync.when(
                data: (invItems) {
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedInventoryItemId,
                    decoration: InputDecoration(
                      labelText: 'Hubungkan dengan Stok Inventaris (Opsional)',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('(Barang baru / tidak terhubung)')),
                      ...invItems.map((item) {
                        return DropdownMenuItem(
                          value: item.item.id,
                          child: Text('${item.item.name} (${item.formattedCurrentStock})'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedInventoryItemId = val;
                        if (val != null) {
                          final selected = invItems.firstWhere((i) => i.item.id == val);
                          _nameController.text = selected.item.name;
                          _unit = selected.item.baseUnit;
                        }
                      });
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Barang Belanja *',
                  hintText: 'Misal: Sabun Mandi, Kopi Sachet, Telur',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama barang wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Jumlah',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                        DropdownMenuItem(value: 'g', child: Text('gram')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'pack', child: Text('pack')),
                      ],
                      onChanged: (val) => setState(() => _unit = val ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Estimasi Harga (Rp, Opsional)',
                  hintText: 'Misal: 25.000',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Misal: Beli merk tertentu atau cari yang promo',
                  prefixIcon: const Icon(Icons.notes_outlined),
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
                    : const Text('Tambah ke Daftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
