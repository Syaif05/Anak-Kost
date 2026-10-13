import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/app_ui_components.dart';
import '../../documents/presentation/providers/documents_providers.dart';
import '../../documents/presentation/widgets/add_document_dialog.dart';
import '../../documents/presentation/widgets/vault_view.dart';
import '../../ocr/presentation/widgets/receipt_scanner_sheet.dart';
import '../domain/models/inventory_models.dart';
import 'providers/inventory_providers.dart';
import 'widgets/add_inventory_item_sheet.dart';
import 'widgets/add_shopping_item_sheet.dart';
import 'widgets/checkout_dialog.dart';
import 'widgets/record_movement_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  String? _selectedCategory; // null = Semua

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryRepositoryProvider).seedDefaultInventoryIfEmpty();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kunci Brankas dan bersihkan memori saat aplikasi keluar dari foreground (DOC03 & Gate DoD)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(vaultMasterKeyProvider.notifier).setKey(null);
      ref.read(vaultUnlockedProvider.notifier).setUnlocked(false);
    }
  }

  void _openFabAction() {
    if (_tabController.index == 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const AddInventoryItemSheet(),
      );
    } else if (_tabController.index == 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const AddShoppingItemSheet(),
      );
    } else {
      final isUnlocked = ref.read(vaultUnlockedProvider);
      final masterKey = ref.read(vaultMasterKeyProvider);
      if (isUnlocked && masterKey != null) {
        showDialog(
          context: context,
          builder: (_) => AddDocumentDialog(masterKey: masterKey),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buka kunci brankas terlebih dahulu untuk menambah dokumen')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Kebutuhan & Stok',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppSquareIconButton(
              icon: Icons.document_scanner_outlined,
              tooltip: 'Pindai Struk Belanja (OCR)',
              onTap: () => ReceiptScannerSheet.show(context),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSecondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryTeal,
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Stok Barang'),
                  Tab(text: 'Belanjaan'),
                  Tab(text: 'Brankas'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: _openFabAction,
          backgroundColor: AppTheme.primaryTeal,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            _tabController.index == 0
                ? 'Tambah Barang'
                : (_tabController.index == 1 ? 'Tambah Belanja' : 'Tambah Dokumen'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockTab(),
          _buildShoppingTab(),
          const VaultView(),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    final itemsAsync = ref.watch(inventoryItemsStreamProvider(_selectedCategory));

    final categories = [
      'Semua',
      'Makanan Pokok',
      'Bahan Masak',
      'Kebersihan',
      'Kebutuhan Mandi',
      'Obat & P3K',
    ];

    return Column(
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: categories.map((cat) {
              final isSelected = (_selectedCategory == null && cat == 'Semua') ||
                  (_selectedCategory == cat);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppPillFilterChip(
                  label: cat,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat == 'Semua' ? null : cat;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Items List
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 28,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum Ada Barang Inventaris',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tambahkan barang kebutuhan kost dengan tombol di bawah',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final itemWithStock = items[index];
                  final isLow = itemWithStock.isLowStock;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isLow ? AppTheme.error.withAlpha(120) : AppTheme.borderColor,
                        width: isLow ? 1.5 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  itemWithStock.item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (isLow)
                                AppStatusBadge.error(
                                  'Stok Menipis',
                                  icon: Icons.warning_amber_rounded,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Stok: ${itemWithStock.formattedCurrentStock}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isLow ? AppTheme.error : AppTheme.primaryTeal,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Batas Min: ${itemWithStock.formattedMinimumStock}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          if (itemWithStock.item.locationLabel != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 14, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  itemWithStock.item.locationLabel!,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.remove, size: 16),
                                label: const Text('Pakai'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textPrimary,
                                  side: const BorderSide(color: AppTheme.borderColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => RecordMovementDialog(
                                      itemWithStock: itemWithStock,
                                      initialMovementType: 'use',
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => RecordMovementDialog(
                                      itemWithStock: itemWithStock,
                                      initialMovementType: 'add',
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Gagal memuat: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildShoppingTab() {
    final listsAsync = ref.watch(shoppingListsStreamProvider);

    return listsAsync.when(
      data: (lists) {
        if (lists.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 28,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum Ada Daftar Belanja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Buat daftar belanja mingguan dengan tombol tambah',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final shoppingList = lists[index];
            final isCompleted = shoppingList.list.status == 'completed';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            shoppingList.list.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        isCompleted
                            ? AppStatusBadge.success('Selesai Belanja')
                            : AppStatusBadge.warning('Belum Selesai'),
                      ],
                    ),
                    if (shoppingList.list.storeHint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Rencana Toko: ${shoppingList.list.storeHint}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: shoppingList.progress,
                              minHeight: 6,
                              backgroundColor: AppTheme.surfaceSecondary,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? AppTheme.success : AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${shoppingList.boughtItems}/${shoppingList.totalItems} item',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...shoppingList.items.map((item) {
                      final isBought = item.status == 'bought';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              isBought ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              size: 16,
                              color: isBought ? AppTheme.success : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.name} (${StockUnit.format(item.requestedQtyMilli, item.unit)})',
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: isBought ? TextDecoration.lineThrough : null,
                                  color: isBought ? AppTheme.textSecondary : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (!isCompleted && shoppingList.pendingItems > 0) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                          label: const Text('Selesaikan Pembelian (Checkout)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => CheckoutDialog(shoppingList: shoppingList),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Gagal memuat: $err')),
    );
  }
}
