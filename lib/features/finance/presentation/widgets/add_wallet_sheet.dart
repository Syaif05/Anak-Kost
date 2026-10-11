import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/money.dart';
import '../providers/finance_providers.dart';

class AddWalletSheet extends ConsumerStatefulWidget {
  const AddWalletSheet({super.key});

  @override
  ConsumerState<AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends ConsumerState<AddWalletSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _selectedType = 'cash';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _types = [
    {'value': 'cash', 'label': 'Tunai', 'icon': Icons.payments_outlined},
    {'value': 'bank', 'label': 'Bank', 'icon': Icons.account_balance_outlined},
    {'value': 'ewallet', 'label': 'E-Wallet', 'icon': Icons.account_balance_wallet_outlined},
    {'value': 'other', 'label': 'Lainnya', 'icon': Icons.credit_card_outlined},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dompet tidak boleh kosong')),
      );
      return;
    }

    final initialBalance = Money.parse(_balanceController.text);

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.createWallet(
        name: name,
        walletType: _selectedType,
        initialBalanceRp: initialBalance,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dompet "$name" berhasil ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan dompet: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Tambah Dompet Baru',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Dompet',
              hintText: 'Misal: BCA, GoPay, Dompet Saku',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.wallet),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Jenis Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: _types.map((t) {
              return ButtonSegment<String>(
                value: t['value'] as String,
                label: Text(t['label'] as String),
                icon: Icon(t['icon'] as IconData),
              );
            }).toList(),
            selected: {_selectedType},
            onSelectionChanged: (set) {
              setState(() => _selectedType = set.first);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Saldo Awal (Opsional)',
              hintText: '0',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
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
                  : const Text('Simpan Dompet'),
            ),
          ),
        ],
      ),
    );
  }
}
