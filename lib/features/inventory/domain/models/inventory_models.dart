import '../../../../core/database/app_database.dart';

/// Helper Konversi dan Formatting Satuan Stok Kebutuhan Kost (Milli-Units)
/// Aturan Bisnis GAMINI.md Bagian 3.3 & Bagian 6.3
/// 1 Unit Dasar = 1.000 Milli-unit (e.g. 5 pcs = 5000 milli-pcs, 1.25 kg = 1.250 g = 1.250.000 milli-g)
abstract class StockUnit {
  static const int milliFactor = 1000;

  /// Mengonversi nilai riil pengguna ke integer milli-unit (disimpan di SQLite)
  static int toMilli(num value) => (value * milliFactor).round();

  /// Mengonversi integer milli-unit ke double unit dasar (untuk kalkulasi/tampilan)
  static double toBase(int milli) => milli / milliFactor;

  /// Memformat angka stok ramah pengguna (misal 5.000 g -> 5 kg, atau 2.500 pcs -> 2,5 pcs)
  static String format(int milli, String unit) {
    final base = toBase(milli);
    final isWhole = base == base.roundToDouble();
    final numberStr = isWhole ? base.toInt().toString() : base.toStringAsFixed(2).replaceAll('.00', '');

    if (unit == 'g' && milli >= 1000000) {
      // Tampilkan dalam kg jika 1.000 gram atau lebih
      final kg = milli / 1000000;
      final kgStr = kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(2);
      return '$kgStr kg ($numberStr g)';
    }

    if (unit == 'ml' && milli >= 1000000) {
      // Tampilkan dalam Liter jika 1.000 ml atau lebih
      final liter = milli / 1000000;
      final literStr = liter == liter.roundToDouble() ? liter.toInt().toString() : liter.toStringAsFixed(2);
      return '$literStr L ($numberStr ml)';
    }

    return '$numberStr $unit';
  }
}

/// DTO Barang Inventaris Beserta Total Stok Terhitung dan Status Ambang Batas
class InventoryItemWithStock {
  final InventoryItem item;
  final int currentStockMilli;

  const InventoryItemWithStock({
    required this.item,
    required this.currentStockMilli,
  });

  /// Apakah stok barang menyentuh atau berada di bawah ambang batas minimum (STK04)
  bool get isLowStock => currentStockMilli <= item.minimumQtyMilli;

  /// Apakah stok berada di angka 0 atau habis
  bool get isOutOfStock => currentStockMilli <= 0;

  /// Format teks stok saat ini
  String get formattedCurrentStock => StockUnit.format(currentStockMilli, item.baseUnit);

  /// Format teks ambang batas minimum
  String get formattedMinimumStock => StockUnit.format(item.minimumQtyMilli, item.baseUnit);
}

/// DTO Daftar Belanja Beserta Daftar Itemnya (STK01)
class ShoppingListWithItems {
  final ShoppingList list;
  final List<ShoppingListItem> items;

  const ShoppingListWithItems({
    required this.list,
    this.items = const [],
  });

  int get totalItems => items.length;
  int get boughtItems => items.where((i) => i.status == 'bought').length;
  int get pendingItems => items.where((i) => i.status == 'pending').length;
  double get progress => totalItems > 0 ? (boughtItems / totalItems) : 0.0;

  int get estimatedTotalRp =>
      items.fold(0, (sum, i) => sum + (i.estimatedTotalRp ?? 0));
}

/// Input Data Item untuk Alur Checkout Belanja Terintegrasi (Gate Test T04)
class CheckoutItemInput {
  final String? inventoryItemId;
  final String? shoppingListItemId;
  final String itemName;
  final int quantityBaseMilli;
  final int totalPaidRp;
  final bool addToStock;
  final String? storeName;

  const CheckoutItemInput({
    this.inventoryItemId,
    this.shoppingListItemId,
    required this.itemName,
    required this.quantityBaseMilli,
    required this.totalPaidRp,
    this.addToStock = true,
    this.storeName,
  });
}
