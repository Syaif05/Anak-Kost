import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/money.dart';
import 'providers/finance_providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _noteController = TextEditingController();

  String? _sourceWalletId;
  String? _destWalletId;
  String? _feeCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
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
    if (_sourceWalletId == null || _destWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet asal dan tujuan transfer')),
      );
      return;
    }

    if (_sourceWalletId == _destWalletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dompet asal dan tujuan tidak boleh sama')),
      );
      return;
    }

    final amountRp = Money.parse(_amountController.text);
    if (amountRp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transfer harus lebih besar dari Rp0')),
      );
      return;
    }

    final feeRp = Money.parse(_feeController.text);
    final localDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.createTransfer(
        sourceWalletId: _sourceWalletId!,
        destWalletId: _destWalletId!,
        amountRp: amountRp,
        feeRp: feeRp,
        feeCategoryId: _feeCategoryId,
        localDate: localDate,
        note: note,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer antar-dompet berhasil diproses')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal melakukan transfer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsStreamProvider);
    final feeCategoriesAsync = ref.watch(categoriesStreamProvider('expense'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Antar-Dompet'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pemilihan Dompet Asal & Tujuan
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      walletsAsync.when(
                        data: (wallets) {
                          return DropdownButtonFormField<String>(
                            initialValue: _sourceWalletId,
                            decoration: const InputDecoration(
                              labelText: 'Dari Dompet (Sumber)',
                              prefixIcon: Icon(Icons.arrow_upward_rounded, color: Colors.red),
                              border: OutlineInputBorder(),
                            ),
                            items: wallets.map((w) {
                              return DropdownMenuItem(
                                value: w.wallet.id,
                                child: Text('${w.wallet.name} (${Money.format(w.balanceRp)})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _sourceWalletId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Icon(Icons.arrow_downward_rounded, color: Colors.blue),
                      ),
                      walletsAsync.when(
                        data: (wallets) {
                          return DropdownButtonFormField<String>(
                            initialValue: _destWalletId,
                            decoration: const InputDecoration(
                              labelText: 'Ke Dompet (Tujuan)',
                              prefixIcon: Icon(Icons.arrow_downward_rounded, color: Colors.green),
                              border: OutlineInputBorder(),
                            ),
                            items: wallets.map((w) {
                              return DropdownMenuItem(
                                value: w.wallet.id,
                                child: Text('${w.wallet.name} (${Money.format(w.balanceRp)})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _destWalletId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nominal Transfer
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Nominal Transfer',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
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
              const SizedBox(height: 16),

              // Biaya Admin / Transfer Fee
              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Biaya Transfer / Admin (Opsional)',
                  hintText: 'Misal: 2.500',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {}); // trigger category display if fee > 0
                },
              ),
              const SizedBox(height: 16),

              // Kategori Biaya (jika ada fee)
              if (Money.parse(_feeController.text) > 0)
                feeCategoriesAsync.when(
                  data: (categories) {
                    if (_feeCategoryId == null && categories.isNotEmpty) {
                      // default ke kategori yang bernama Biaya Transfer jika ada
                      final match = categories.where((c) => c.name.toLowerCase().contains('transfer')).firstOrNull;
                      _feeCategoryId = match?.id ?? categories.first.id;
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _feeCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori Biaya Transfer',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_outlined),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _feeCategoryId = val),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              if (Money.parse(_feeController.text) > 0) const SizedBox(height: 16),

              // Tanggal Transfer
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate),
                ),
                onPressed: _pickDate,
              ),
              const SizedBox(height: 16),

              // Catatan
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Misal: Top up GoPay, Bayar tagihan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Proses Transfer',
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
