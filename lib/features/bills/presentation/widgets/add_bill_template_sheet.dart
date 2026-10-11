import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/money.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../providers/bills_providers.dart';

class AddBillTemplateSheet extends ConsumerStatefulWidget {
  const AddBillTemplateSheet({super.key});

  @override
  ConsumerState<AddBillTemplateSheet> createState() => _AddBillTemplateSheetState();
}

class _AddBillTemplateSheetState extends ConsumerState<AddBillTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategoryId;
  String _frequency = 'monthly'; // monthly, weekly, yearly, once
  DateTime _anchorDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickAnchorDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _anchorDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori pengeluaran tagihan')),
      );
      return;
    }

    final amountRp = Money.parse(_amountController.text);
    if (amountRp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal estimasi tagihan harus lebih dari Rp 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(billsRepositoryProvider);
      final anchorDateStr = DateFormat('yyyy-MM-dd').format(_anchorDate);

      await repo.createBillTemplate(
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        estimatedAmountRp: amountRp,
        frequency: _frequency,
        anchorDate: anchorDateStr,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template tagihan berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat tagihan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesStreamProvider('expense'));

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
                    'Tambah Tagihan Rutin',
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
                  labelText: 'Nama Tagihan *',
                  hintText: 'Misal: Sewa Kost Kamar 204, WiFi, Laundry',
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama tagihan wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Text('Tidak ada kategori pengeluaran');
                  }
                  _selectedCategoryId ??= categories.first.id;
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Kategori Pengeluaran *',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Estimasi Nominal Tagihan (Rp) *',
                  hintText: 'Misal: 1.000.000',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nominal wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              const Text('Frekuensi Tagihan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'monthly', label: Text('Bulanan')),
                  ButtonSegment(value: 'weekly', label: Text('Mingguan')),
                  ButtonSegment(value: 'yearly', label: Text('Tahunan')),
                ],
                selected: {_frequency},
                onSelectionChanged: (val) => setState(() => _frequency = val.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text('Tanggal Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(_anchorDate)}'),
                      onPressed: _pickAnchorDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Misal: Jatuh tempo tiap tanggal ${_anchorDate.day}, transfer ke rekening bapak kost',
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
                    : const Text('Simpan Template Tagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
