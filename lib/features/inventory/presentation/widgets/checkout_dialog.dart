import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/money.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../domain/models/inventory_models.dart';
import '../providers/inventory_providers.dart';

class CheckoutDialog extends ConsumerStatefulWidget {
  final ShoppingListWithItems shoppingList;

  const CheckoutDialog({super.key, required this.shoppingList});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _storeController = TextEditingController();
  late List<TextEditingController> _priceControllers;
  late List<TextEditingController> _qtyControllers;
  late List<bool> _addToStockFlags;

  String? _selectedWalletId;
  String? _selectedCategoryId;
  final DateTime _purchaseDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _storeController.text = widget.shoppingList.list.storeHint ?? '';

    final items = widget.shoppingList.items.where((i) => i.status != 'bought').toList();
    _priceControllers = items.map((i) {
      final est = i.estimatedTotalRp ?? 0;
      return TextEditingController(text: est > 0 ? Money.format(est, withSymbol: false) : '');
    }).toList();

    _qtyControllers = items.map((i) {
      return TextEditingController(text: StockUnit.toBase(i.requestedQtyMilli).toString());
    }).toList();

    _addToStockFlags = List.generate(items.length, (_) => true);
  }

  @override
  void dispose() {
    _storeController.dispose();
    for (final c in _priceControllers) {
      c.dispose();
    }
    for (final c in _qtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _grandTotalRp {
    var total = 0;
    for (final c in _priceControllers) {
      total += Money.parse(c.text);
    }
    return total;
  }

  Future<void> _submitCheckout() async {
    final pendingItems = widget.shoppingList.items.where((i) => i.status != 'bought').toList();
    if (pendingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada item yang dapat di-checkout')),
      );
      return;
    }

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet sumber pembayaran')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori pengeluaran belanja')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final checkoutInputs = <CheckoutItemInput>[];

      for (var i = 0; i < pendingItems.length; i++) {
        final item = pendingItems[i];
        final price = Money.parse(_priceControllers[i].text);
        final rawQty = double.tryParse(_qtyControllers[i].text.replaceAll(',', '.')) ??
            StockUnit.toBase(item.requestedQtyMilli);

        checkoutInputs.add(CheckoutItemInput(
          inventoryItemId: item.inventoryItemId,
          shoppingListItemId: item.id,
          itemName: item.name,
          quantityBaseMilli: StockUnit.toMilli(rawQty),
          totalPaidRp: price,
          addToStock: _addToStockFlags[i],
          storeName: _storeController.text.trim().isEmpty ? null : _storeController.text.trim(),
        ));
      }

      final localDateStr = DateFormat('yyyy-MM-dd').format(_purchaseDate);

      await repo.checkoutShoppingList(
        shoppingListId: widget.shoppingList.list.id,
        walletId: _selectedWalletId!,
        expenseCategoryId: _selectedCategoryId!,
        items: checkoutInputs,
        localDate: localDateStr,
        storeName: _storeController.text.trim().isEmpty ? null : _storeController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Belanja selesai! Pengeluaran ${Money.format(_grandTotalRp)} & penambahan stok berhasil dicatat.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal checkout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletsAsync = ref.watch(walletsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider('expense'));
    final pendingItems = widget.shoppingList.items.where((i) => i.status != 'bought').toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selesaikan Pembelian',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konfirmasi barang yang dibeli untuk "${widget.shoppingList.list.name}":',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(pendingItems.length, (i) {
                        final item = pendingItems[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Text('Satuan: ${item.unit}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _qtyControllers[i],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Jumlah Riil',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceControllers[i],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Harga Riil (Rp)',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.inventoryItemId != null) ...[
                                  const SizedBox(height: 4),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text('Tambah ke stok inventaris', style: TextStyle(fontSize: 12)),
                                    value: _addToStockFlags[i],
                                    onChanged: (val) => setState(() => _addToStockFlags[i] = val ?? true),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      walletsAsync.when(
                        data: (wallets) {
                          if (wallets.isEmpty) return const Text('Tidak ada dompet');
                          _selectedWalletId ??= wallets.first.wallet.id;
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedWalletId,
                            decoration: InputDecoration(
                              labelText: 'Bayar dengan Dompet *',
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: wallets.map((w) {
                              return DropdownMenuItem(
                                value: w.wallet.id,
                                child: Text('${w.wallet.name} (${Money.format(w.balanceRp)})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedWalletId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      categoriesAsync.when(
                        data: (categories) {
                          if (categories.isEmpty) return const Text('Tidak ada kategori');
                          _selectedCategoryId ??= categories.first.id;
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedCategoryId,
                            decoration: InputDecoration(
                              labelText: 'Kategori Biaya *',
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: categories.map((c) {
                              return DropdownMenuItem(value: c.id, child: Text(c.name));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCategoryId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _storeController,
                        decoration: InputDecoration(
                          labelText: 'Nama Toko / Tempat Belanja',
                          hintText: 'Misal: Superindo, Indomaret, Warung Madura',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembelian:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    Money.format(_grandTotalRp),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Konfirmasi & Catat Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
