import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/core_providers.dart';
import '../../documents/presentation/providers/documents_providers.dart';
import '../../finance/presentation/providers/finance_providers.dart';
import '../../inventory/domain/models/inventory_models.dart';
import '../../inventory/presentation/providers/inventory_providers.dart';
import '../domain/models/receipt_draft.dart';

/// Layar Review Draf Struk Belanja (PRD GAMINI.md Bagian 3.6.2 & Bagian 10.5 Butir 3)
/// ATURAN MUTLAK: Tidak ada transaksi finansial yang disimpan otomatis dari OCR tanpa konfirmasi pengguna!
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  final ReceiptDraft initialDraft;
  final String? originalImagePath;

  const ReceiptReviewScreen({
    super.key,
    required this.initialDraft,
    this.originalImagePath,
  });

  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _totalController;
  late DateTime _selectedDate;

  String? _selectedWalletId;
  String? _selectedCategoryId;
  bool _syncWithInventory = false;
  bool _isSaving = false;

  late List<ReceiptDraftItem> _items;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.initialDraft.merchantCandidate ?? '');
    _totalController = TextEditingController(
      text: widget.initialDraft.totalRpCandidate > 0 ? widget.initialDraft.totalRpCandidate.toString() : '',
    );

    if (widget.initialDraft.localDateCandidate != null) {
      _selectedDate = DateTime.tryParse(widget.initialDraft.localDateCandidate!) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }

    _items = List<ReceiptDraftItem>.from(widget.initialDraft.items);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _recalculateTotalFromItems() {
    final sum = _items.fold<int>(0, (prev, it) => prev + it.lineTotalRp);
    if (sum > 0) {
      setState(() {
        _totalController.text = sum.toString();
      });
    }
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Item Belanja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama Barang *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kuantitas', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Harga (Rp) *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
              final price = int.tryParse(priceCtrl.text.trim().replaceAll('.', '')) ?? 0;

              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _items.add(ReceiptDraftItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    quantity: qty,
                    unit: 'pcs',
                    unitPriceRp: (price / qty).round(),
                    lineTotalRp: price,
                  ));
                });
                _recalculateTotalFromItems();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('Pilih dompet pembayaran terlebih dahulu')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('Pilih kategori pengeluaran terlebih dahulu')),
      );
      return;
    }

    final total = int.tryParse(_totalController.text.trim().replaceAll('.', '')) ?? 0;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('Nominal total belanja harus lebih dari Rp 0')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final financeRepo = ref.read(financeRepositoryProvider);
      final inventoryRepo = ref.read(inventoryRepositoryProvider);
      final documentsRepo = ref.read(documentsRepositoryProvider);
      final keyMgr = ref.read(keyManagerProvider);

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final merchantName = _merchantController.text.trim().isEmpty ? 'Toko Struk' : _merchantController.text.trim();

      // 1. Catat Transaksi Pengeluaran Keuangan (FIN01 & Gate Dodd)
      final txId = await financeRepo.createExpense(
        walletId: _selectedWalletId!,
        amountRp: total,
        categoryId: _selectedCategoryId!,
        localDate: dateStr,
        merchant: merchantName,
        note: 'Struk OCR: ${_items.map((e) => e.name).join(", ")}',
      );

      // 2. Lampirkan Foto Struk Asli Terenkripsi AES-256-GCM (DOC03 & IMG)
      if (widget.originalImagePath != null) {
        final imgFile = File(widget.originalImagePath!);
        if (await imgFile.exists()) {
          final fileBytes = await imgFile.readAsBytes();
          var masterKey = ref.read(vaultMasterKeyProvider);
          if (masterKey == null) {
            masterKey = await keyMgr.getLocalMasterKey('vault');
            if (masterKey == null) {
              final newKey = keyMgr.generateMasterKey();
              await keyMgr.saveLocalMasterKey('vault', newKey);
              masterKey = newKey;
            }
          }

          await documentsRepo.attachEvidenceToTransaction(
            transactionId: txId,
            fileBytes: fileBytes,
            masterKey: masterKey,
            mimeType: 'image/jpeg',
          );
        }
      }

      // 3. Jika dipilih, Sinkronkan & Tambah Stok ke Inventaris (STK)
      if (_syncWithInventory && _items.isNotEmpty) {
        final existingInventory = await inventoryRepo.dao.watchInventoryItemsWithStock().first;
        for (final draftItem in _items) {
          // Cari apakah barang sudah ada di inventaris (case-insensitive)
          InventoryItemWithStock? matched;
          for (final it in existingInventory) {
            if (it.item.name.toLowerCase().contains(draftItem.name.toLowerCase()) ||
                draftItem.name.toLowerCase().contains(it.item.name.toLowerCase())) {
              matched = it;
              break;
            }
          }

          if (matched != null) {
            final deltaMilli = StockUnit.toMilli(draftItem.quantity);
            await inventoryRepo.recordMovement(
              itemId: matched.item.id,
              movementType: 'add',
              quantityDeltaMilli: deltaMilli,
              reason: 'Penambahan stok dari struk $merchantName',
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Transaksi pengeluaran berhasil disimpan bersama bukti struk terenkripsi!'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Gagal menyimpan transaksi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletsAsync = ref.watch(walletsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider('expense'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Draf Struk', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (widget.originalImagePath != null)
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: 'Lihat Foto Asli',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppBar(
                          title: const Text('Foto Asli Struk'),
                          automaticallyImplyLeading: false,
                          actions: [
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                          ],
                        ),
                        InteractiveViewer(
                          child: Image.file(
                            File(widget.originalImagePath!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveTransaction,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Konfirmasi & Simpan Pengeluaran',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Peringatan Parser jika ada
            if (widget.initialDraft.warnings.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('Perhatian Parser OCR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...widget.initialDraft.warnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $w', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Card 1: Informasi Toko & Tanggal
            Card(
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
                    Text('Informasi Transaksi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _merchantController,
                      decoration: InputDecoration(
                        labelText: 'Nama Toko / Merchant *',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama toko wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tanggal Transaksi',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Nominal & Dompet Pembayaran
            Card(
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
                    Text('Nominal & Pembayaran', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _totalController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Total Belanja (IDR) *',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Total wajib diisi';
                        final num = int.tryParse(val.replaceAll('.', ''));
                        if (num == null || num <= 0) return 'Total harus lebih dari 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Badge Indikator Ringkasan Finansial Terdeteksi
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (widget.initialDraft.subtotalRp != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text('Subtotal: ${_currencyFormat.format(widget.initialDraft.subtotalRp)}', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          if (widget.initialDraft.cashTenderedRp != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text('Tunai: ${_currencyFormat.format(widget.initialDraft.cashTenderedRp)}', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          if (widget.initialDraft.changeRp != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text('Kembalian: ${_currencyFormat.format(widget.initialDraft.changeRp)}', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown Dompet
                    walletsAsync.when(
                      data: (wallets) {
                        if (_selectedWalletId == null && wallets.isNotEmpty) {
                          _selectedWalletId = wallets.first.wallet.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedWalletId,
                          decoration: InputDecoration(
                            labelText: 'Dompet Pembayaran *',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: wallets.map((w) {
                            return DropdownMenuItem(
                              value: w.wallet.id,
                              child: Text('${w.wallet.name} (${_currencyFormat.format(w.balanceRp)})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedWalletId = val),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Gagal memuat dompet: $e'),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown Kategori Pengeluaran
                    categoriesAsync.when(
                      data: (categories) {
                        if (_selectedCategoryId == null && categories.isNotEmpty) {
                          _selectedCategoryId = categories.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: 'Kategori Pengeluaran *',
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
                      error: (e, _) => Text('Gagal memuat kategori: $e'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Rincian Item Belanja
            Card(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Item Belanja (${_items.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah Item'),
                          onPressed: _showAddItemDialog,
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('Tidak ada item individual terdeteksi (Hanya total yang disimpan)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      )
                    else
                      ..._items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final it = entry.value;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${it.quantity} ${it.unit} @ ${_currencyFormat.format(it.unitPriceRp ?? it.lineTotalRp)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_currencyFormat.format(it.lineTotalRp), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(idx);
                                  });
                                  _recalculateTotalFromItems();
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),

                    // Opsi Sinkronisasi ke Stok Inventaris
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _syncWithInventory,
                      onChanged: (val) => setState(() => _syncWithInventory = val ?? false),
                      title: const Text('Tambahkan barang belanjaan ke Stok Inventaris', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Mencocokkan barang yang ada di modul inventaris dan menambah stok otomatis', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
