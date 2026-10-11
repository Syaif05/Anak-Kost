import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/agenda_providers.dart';
import '../../domain/models/agenda_models.dart';

class AgendaCalendarView extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const AgendaCalendarView({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  ConsumerState<AgendaCalendarView> createState() => _AgendaCalendarViewState();
}

class _AgendaCalendarViewState extends ConsumerState<AgendaCalendarView> {
  Future<void> _cancelOccurrence(AgendaOccurrence occ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Agenda Ini?'),
        content: Text('Apakah Anda ingin membatalkan kejadian "${occ.title}" untuk tanggal ${DateFormat('dd MMM yyyy').format(occ.start)} (misal libur nasional/cuti)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(agendaRepositoryProvider);
      final originalStartLocal = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(occ.start);

      await repo.addEventException(
        eventId: occ.eventId,
        occurrenceKey: occ.occurrenceKey,
        originalStartLocal: originalStartLocal,
        action: 'cancel',
      );

      if (mounted) {
        ref.invalidate(agendaOccurrencesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agenda hari ini berhasil dibatalkan (alarm dinonaktifkan)')),
        );
      }
    }
  }

  Future<void> _overrideOccurrence(AgendaOccurrence occ) async {
    final titleCtrl = TextEditingController(text: occ.title);
    final locCtrl = TextEditingController(text: occ.locationText ?? 'Kost / WFH');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Agenda Khusus Hari Ini'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Judul Baru', hintText: 'Misal: Magang WFH'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'Lokasi Baru', hintText: 'Misal: Kamar Kost'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );

    if (result == true) {
      final repo = ref.read(agendaRepositoryProvider);
      final originalStartLocal = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(occ.start);

      await repo.addEventException(
        eventId: occ.eventId,
        occurrenceKey: occ.occurrenceKey,
        originalStartLocal: originalStartLocal,
        action: 'override',
        overridePayload: {
          'title': titleCtrl.text.trim(),
          'location_text': locCtrl.text.trim(),
        },
      );

      if (mounted) {
        ref.invalidate(agendaOccurrencesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal khusus hari ini berhasil diperbarui')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selectedDate;

    // Evaluasi occurrence untuk hari yang dipilih (00:00:00 s/d 23:59:59)
    final rangeStart = DateTime(selected.year, selected.month, selected.day, 0, 0, 0);
    final rangeEnd = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);

    final occurrencesAsync = ref.watch(agendaOccurrencesProvider(DateRangeParams(start: rangeStart, end: rangeEnd)));

    return Column(
      children: [
        // Horizontal Date Selector Strip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(selected),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Hari Ini'),
                    onPressed: () => widget.onDateSelected(DateTime.now()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(14, (i) {
                    final day = DateTime.now().subtract(const Duration(days: 3)).add(Duration(days: i));
                    final isSelected = day.year == selected.year &&
                        day.month == selected.month &&
                        day.day == selected.day;
                    final isToday = day.year == DateTime.now().year &&
                        day.month == DateTime.now().month &&
                        day.day == DateTime.now().day;

                    return GestureDetector(
                      onTap: () => widget.onDateSelected(day),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isToday ? theme.colorScheme.primaryContainer.withAlpha(80) : Colors.transparent),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isToday ? theme.colorScheme.primary.withAlpha(120) : Colors.transparent),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('E', 'id_ID').format(day),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List of Occurrences
        Expanded(
          child: occurrencesAsync.when(
            data: (occurrences) {
              if (occurrences.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.coffee_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak Ada Agenda Hari Ini',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Waktunya bersantai, istirahat, atau fokus belajar! ☕',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: occurrences.length,
                itemBuilder: (context, index) {
                  final occ = occurrences[index];
                  final timeRange =
                      '${DateFormat('HH:mm').format(occ.start)} - ${DateFormat('HH:mm').format(occ.end)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: occ.isOverridden
                            ? Colors.amber.shade400
                            : theme.colorScheme.outlineVariant.withAlpha(100),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: theme.colorScheme.onPrimaryContainer),
                                    const SizedBox(width: 4),
                                    Text(
                                      timeRange,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (occ.isRecurring) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.repeat, size: 12, color: Colors.blue),
                                      SizedBox(width: 2),
                                      Text('Mingguan', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                    ],
                                  ),
                                ),
                              ],
                              if (occ.isOverridden) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Diubah',
                                    style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) {
                                  if (action == 'cancel') {
                                    _cancelOccurrence(occ);
                                  } else if (action == 'override') {
                                    _overrideOccurrence(occ);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'override',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_calendar, size: 18),
                                        SizedBox(width: 8),
                                        Text('Ubah Hari Ini (WFH/dll)'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        Icon(Icons.event_busy, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Batalkan Hari Ini (Libur)', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            occ.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (occ.locationText != null && occ.locationText!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    occ.locationText!,
                                    style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (occ.notes != null && occ.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              occ.notes!,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
          ),
        ),
      ],
    );
  }
}
