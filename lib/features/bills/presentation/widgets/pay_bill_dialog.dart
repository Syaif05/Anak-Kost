import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/money.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../domain/models/bill_models.dart';
import '../providers/bills_providers.dart';

class PayBillDialog extends ConsumerStatefulWidget {
  final BillOccurrenceWithStatus occurrenceWithStatus;

  const PayBillDialog({super.key, required this.occurrenceWithStatus});

  @override
  ConsumerState<PayBillDialog> createState() => _PayBillDialogState();
}

class _PayBillDialogState extends ConsumerState<PayBillDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();

  String? _selectedWalletId;
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default nominal set to sisa tagihan
    _amountController = TextEditingController(
      text: Money.format(widget.occurrenceWithStatus.remainingRp, withSymbol: false),
    );
    _noteController.text = 'Pembayaran ${widget.occurrenceWithStatus.template.name}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet sumber pembayaran')),
      );
      return;
    }

    final amountRp = Money.parse(_amountController.text);
    if (amountRp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran harus lebih dari Rp 0')),
      );
      return;
    }

    if (amountRp > widget.occurrenceWithStatus.remainingRp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nominal pembayaran melebihi sisa tagihan (${Money.format(widget.occurrenceWithStatus.remainingRp)})')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(billsRepositoryProvider);
      final localDateStr = DateFormat('yyyy-MM-dd').format(_paymentDate);

      await repo.payBillOccurrence(
        occurrenceId: widget.occurrenceWithStatus.occurrence.id,
        walletId: _selectedWalletId!,
        amountRp: amountRp,
        localDate: localDateStr,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pembayaran ${Money.format(amountRp)} berhasil dicatat!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses pembayaran: $e')),
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
    final occ = widget.occurrenceWithStatus;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      'Bayar Tagihan',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        occ.template.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Tagihan:', style: TextStyle(fontSize: 13)),
                          Text(Money.format(occ.effectiveAmountDueRp),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sudah Dibayar:', style: TextStyle(fontSize: 13)),
                          Text(Money.format(occ.totalPaidRp),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Tagihan:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            Money.format(occ.remainingRp),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                walletsAsync.when(
                  data: (wallets) {
                    if (wallets.isEmpty) {
                      return const Text('Tidak ada dompet aktif');
                    }
                    _selectedWalletId ??= wallets.first.wallet.id;
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedWalletId,
                      decoration: InputDecoration(
                        labelText: 'Bayar Menggunakan *',
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
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nominal yang Dibayar (Rp) *',
                    hintText: 'Misal: 400.000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    helperText: 'Bisa dibayar sebagian atau langsung lunas',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Nominal wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Tanggal Bayar: ${DateFormat('dd MMM yyyy').format(_paymentDate)}'),
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Catatan Pembayaran',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Konfirmasi Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
