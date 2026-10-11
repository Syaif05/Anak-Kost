import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/money.dart';
import '../providers/finance_providers.dart';

class AddBudgetSheet extends ConsumerStatefulWidget {
  const AddBudgetSheet({super.key});

  @override
  ConsumerState<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<AddBudgetSheet> {
  String? _selectedCategoryId;
  final _limitController = TextEditingController();
  int _warningPercent = 80;
  bool _isLoading = false;

  late final String _currentMonthStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonthStart = DateFormat('yyyy-MM-01').format(now);
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori pengeluaran')),
      );
      return;
    }

    final limitRp = Money.parse(_limitController.text);
    if (limitRp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limit budget harus lebih besar dari Rp0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.setBudget(
        categoryId: _selectedCategoryId!,
        monthStart: _currentMonthStart,
        limitRp: limitRp,
        warningPercent: _warningPercent,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget kategori berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan budget: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider('expense'));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Atur Budget Bulan Ini',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const Text('Belum ada kategori pengeluaran tersedia.');
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori Pengeluaran',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCategoryId = val);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas Budget Bulanan',
              hintText: '500.000',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Peringatan Limit (%)', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('$_warningPercent%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _warningPercent.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            label: '$_warningPercent%',
            onChanged: (val) {
              setState(() => _warningPercent = val.round());
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan Budget'),
            ),
          ),
        ],
      ),
    );
  }
}
