import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../documents/presentation/providers/documents_providers.dart';
import '../../documents/presentation/widgets/add_document_dialog.dart';
import '../../documents/presentation/widgets/vault_view.dart';
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
      appBar: AppBar(
        title: const Text(
          'Kebutuhan, Stok & Brankas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stok Barang'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Daftar Belanja'),
            Tab(icon: Icon(Icons.shield_outlined), text: 'Brankas Dokumen'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFabAction,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0
              ? 'Tambah Barang'
              : (_tabController.index == 1 ? 'Tambah Belanja' : 'Tambah Dokumen'),
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
    final theme = Theme.of(context);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: categories.map((cat) {
              final isSelected = (_selectedCategory == null && cat == 'Semua') ||
                  (_selectedCategory == cat);

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = cat == 'Semua' ? null : cat;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),

        // Items List
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Barang Inventaris',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tambahkan barang kebutuhan kost dengan tombol di bawah',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final itemWithStock = items[index];
                  final isLow = itemWithStock.isLowStock;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isLow
                            ? Colors.red.shade300
                            : theme.colorScheme.outlineVariant.withAlpha(100),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              if (isLow) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha(25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber, size: 12, color: Colors.red),
                                      SizedBox(width: 4),
                                      Text(
                                        'Stok Menipis',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Stok: ${itemWithStock.formattedCurrentStock}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? Colors.red.shade700 : theme.colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Batas Min: ${itemWithStock.formattedMinimumStock}',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                          if (itemWithStock.item.locationLabel != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  itemWithStock.item.locationLabel!,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.remove, size: 16),
                                label: const Text('Pakai'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final theme = Theme.of(context);
    final listsAsync = ref.watch(shoppingListsStreamProvider);

    return listsAsync.when(
      data: (lists) {
        if (lists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  'Belum Ada Daftar Belanja',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buat daftar belanja mingguan dengan tombol tambah',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final shoppingList = lists[index];
            final isCompleted = shoppingList.list.status == 'completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
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
                        Expanded(
                          child: Text(
                            shoppingList.list.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted ? Colors.green.withAlpha(25) : Colors.orange.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCompleted ? 'Selesai Belanja' : 'Belum Selesai',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (shoppingList.list.storeHint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Rencana Toko: ${shoppingList.list.storeHint}',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: shoppingList.progress,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              color: isCompleted ? Colors.green : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${shoppingList.boughtItems}/${shoppingList.totalItems} item',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.outline),
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
                              isBought ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 16,
                              color: isBought ? Colors.green : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.name} (${StockUnit.format(item.requestedQtyMilli, item.unit)})',
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: isBought ? TextDecoration.lineThrough : null,
                                  color: isBought ? theme.colorScheme.outline : null,
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
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: const Text('Selesaikan Pembelian (Checkout)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
