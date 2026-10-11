import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/money.dart';
import '../domain/models/finance_models.dart';
import 'providers/finance_providers.dart';

class SavingGoalsScreen extends ConsumerWidget {
  const SavingGoalsScreen({super.key});

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    DateTime? targetDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Target Tabungan Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Target',
                    hintText: 'Misal: Beli Laptop, Dana Darurat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal Target',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    targetDate == null
                        ? 'Pilih Target Tanggal (Opsional)'
                        : DateFormat('d MMMM yyyy', 'id_ID').format(targetDate!),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      setState(() => targetDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final targetRp = Money.parse(targetCtrl.text);
                if (name.isEmpty || targetRp <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Isi nama dan target nominal dengan benar')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final repo = ref.read(financeRepositoryProvider);
                await repo.createSavingGoal(
                  name: name,
                  targetRp: targetRp,
                  targetDate: targetDate != null ? DateFormat('yyyy-MM-dd').format(targetDate!) : null,
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingGoalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Tabungan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Target Baru'),
        onPressed: () => _showAddGoalDialog(context, ref),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada target tabungan.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tetapkan target seperti Dana Darurat atau Kost Semester Depan.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _SavingGoalCard(item: goals[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _SavingGoalCard extends ConsumerWidget {
  final SavingGoalWithProgress item;

  const _SavingGoalCard({required this.item});

  void _showAllocateDialog(BuildContext context, WidgetRef ref, {required bool isWithdraw}) {
    final amountCtrl = TextEditingController();
    String? selectedWalletId;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final walletsAsync = ref.watch(walletsStreamProvider);

          return AlertDialog(
            title: Text(isWithdraw ? 'Tarik Alokasi Tabungan' : 'Alokasikan Dana ke Tabungan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Target: ${item.goal.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  walletsAsync.when(
                    data: (wallets) {
                      if (selectedWalletId == null && wallets.isNotEmpty) {
                        selectedWalletId = wallets.first.wallet.id;
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: selectedWalletId,
                        decoration: InputDecoration(
                          labelText: isWithdraw ? 'Ke Dompet' : 'Dari Dompet',
                          border: const OutlineInputBorder(),
                        ),
                        items: wallets.map((w) {
                          return DropdownMenuItem(
                            value: w.wallet.id,
                            child: Text('${w.wallet.name} (${Money.format(w.balanceRp)})'),
                          );
                        }).toList(),
                        onChanged: (val) => selectedWalletId = val,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = Money.parse(amountCtrl.text);
                  if (amount <= 0 || selectedWalletId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nominal harus valid dan dompet dipilih')),
                    );
                    return;
                  }

                  try {
                    final repo = ref.read(financeRepositoryProvider);
                    if (isWithdraw) {
                      await repo.withdrawSavings(
                        goalId: item.goal.id,
                        walletId: selectedWalletId!,
                        amountRp: amount,
                      );
                    } else {
                      await repo.allocateSavings(
                        goalId: item.goal.id,
                        walletId: selectedWalletId!,
                        amountRp: amount,
                      );
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isWithdraw
                                ? 'Alokasi berhasil ditarik kembali'
                                : 'Dana berhasil dialokasikan ke tabungan',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal: $e')),
                      );
                    }
                  }
                },
                child: Text(isWithdraw ? 'Tarik' : 'Alokasikan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final clampedRatio = item.percentage > 1.0 ? 1.0 : item.percentage;

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
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
                    item.goal.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isAchieved ? Colors.green.withAlpha(30) : Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(item.percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: item.isAchieved ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: clampedRatio,
                minHeight: 10,
                backgroundColor: Colors.grey.withAlpha(40),
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.isAchieved ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Terkumpul', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      Money.format(item.allocatedRp),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      Money.format(item.goal.targetRp),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: item.allocatedRp > 0
                      ? () => _showAllocateDialog(context, ref, isWithdraw: true)
                      : null,
                  child: const Text('Tarik Alokasi'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _showAllocateDialog(context, ref, isWithdraw: false),
                  child: const Text('Alokasikan Dana'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
