import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/money.dart';
import 'providers/finance_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialKind; // 'expense' or 'income'

  const AddTransactionScreen({
    super.key,
    this.initialKind = 'expense',
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late String _kind;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _merchantController = TextEditingController();

  String? _selectedWalletId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<int> _quickAmounts = [10000, 20000, 50000, 100000];

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int val) {
    final current = Money.parse(_amountController.text);
    final next = current + val;
    _amountController.text = Money.format(next, withSymbol: false);
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final amountRp = Money.parse(_amountController.text);
    if (amountRp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi harus lebih besar dari Rp0')),
      );
      return;
    }

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih dompet')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih kategori')),
      );
      return;
    }

    final localDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    final merchant = _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim();

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      if (_kind == 'expense') {
        await repo.createExpense(
          walletId: _selectedWalletId!,
          amountRp: amountRp,
          categoryId: _selectedCategoryId!,
          localDate: localDate,
          note: note,
          merchant: merchant,
        );
      } else {
        await repo.createIncome(
          walletId: _selectedWalletId!,
          amountRp: amountRp,
          categoryId: _selectedCategoryId!,
          localDate: localDate,
          note: note,
          merchant: merchant,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _kind == 'expense' ? 'Pengeluaran berhasil dicatat' : 'Pemasukan berhasil dicatat',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencatat transaksi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider(_kind));

    final theme = Theme.of(context);
    final isExpense = _kind == 'expense';

    return Scaffold(
      appBar: AppBar(
        title: Text(isExpense ? 'Catat Pengeluaran' : 'Catat Pemasukan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Jenis Transaksi
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Pengeluaran'),
                      icon: Icon(Icons.arrow_upward, color: Colors.red),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text('Pemasukan'),
                      icon: Icon(Icons.arrow_downward, color: Colors.teal),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (set) {
                    setState(() {
                      _kind = set.first;
                      _selectedCategoryId = null; // reset category on switch
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Input Nominal Besar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isExpense
                      ? Colors.red.withAlpha(15)
                      : Colors.teal.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpense ? Colors.red.shade200 : Colors.teal.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nominal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isExpense ? Colors.red.shade700 : Colors.teal.shade700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Rp ',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isExpense ? Colors.red.shade800 : Colors.teal.shade800,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isExpense ? Colors.red.shade800 : Colors.teal.shade800,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              // Formatter instan
                              final parsed = Money.parse(val);
                              if (parsed > 0 && val != Money.format(parsed, withSymbol: false)) {
                                final newText = Money.format(parsed, withSymbol: false);
                                _amountController.value = TextEditingValue(
                                  text: newText,
                                  selection: TextSelection.collapsed(offset: newText.length),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick Nominal Chips
              Wrap(
                spacing: 8,
                children: _quickAmounts.map((q) {
                  return ActionChip(
                    label: Text('+ ${Money.format(q)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () => _addQuickAmount(q),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Pilih Dompet
              const Text('Pilih Dompet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              walletsAsync.when(
                data: (wallets) {
                  if (wallets.isEmpty) {
                    return const Text('Belum ada dompet. Tambahkan dompet terlebih dahulu.');
                  }
                  if (_selectedWalletId == null && wallets.isNotEmpty) {
                    _selectedWalletId = wallets.first.wallet.id;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedWalletId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
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
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 20),

              // Pilih Kategori
              const Text('Pilih Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Text('Belum ada kategori tersedia.');
                  }
                  if (_selectedCategoryId == null && categories.isNotEmpty) {
                    _selectedCategoryId = categories.first.id;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 20),

              // Tanggal Transaksi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate),
                      ),
                      onPressed: _pickDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Merchant / Tempat & Catatan
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Toko (Opsional)',
                  hintText: 'Misal: Warung Makan, Indomaret, PLN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Misal: Sarapan pagi, Patungan teman',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isExpense ? theme.colorScheme.primary : Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Simpan Transaksi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
