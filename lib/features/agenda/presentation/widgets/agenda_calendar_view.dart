import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/app_ui_components.dart';
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
    final selected = widget.selectedDate;

    // Evaluasi occurrence untuk hari yang dipilih (00:00:00 s/d 23:59:59)
    final rangeStart = DateTime(selected.year, selected.month, selected.day, 0, 0, 0);
    final rangeEnd = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);

    final occurrencesAsync = ref.watch(agendaOccurrencesProvider(DateRangeParams(start: rangeStart, end: rangeEnd)));

    return Column(
      children: [
        // Horizontal Date Selector Strip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(selected),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onDateSelected(DateTime.now()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.today_rounded, size: 14, color: AppTheme.primaryTeal),
                          SizedBox(width: 4),
                          Text(
                            'Hari Ini',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryTeal
                              : (isToday ? AppTheme.primaryTealContainer : Colors.transparent),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryTeal
                                : (isToday ? AppTheme.primaryTeal : AppTheme.borderColor),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('E', 'id_ID').format(day),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white70
                                    : (isToday ? AppTheme.primaryTeal : AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : (isToday ? AppTheme.primaryTeal : AppTheme.textPrimary),
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

        // List of Occurrences
        Expanded(
          child: occurrencesAsync.when(
            data: (occurrences) {
              if (occurrences.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(
                            Icons.coffee_outlined,
                            size: 28,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tidak Ada Agenda Hari Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Waktunya bersantai, istirahat, atau fokus belajar! ☕',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                itemCount: occurrences.length,
                itemBuilder: (context, index) {
                  final occ = occurrences[index];
                  final timeRange =
                      '${DateFormat('HH:mm').format(occ.start)} - ${DateFormat('HH:mm').format(occ.end)}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: occ.isOverridden ? AppTheme.warning.withAlpha(120) : AppTheme.borderColor,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppStatusBadge.neutral(
                                timeRange,
                                icon: Icons.access_time_rounded,
                              ),
                              if (occ.isRecurring) ...[
                                const SizedBox(width: 6),
                                AppStatusBadge(
                                  label: 'Mingguan',
                                  backgroundColor: AppTheme.primaryTealContainer,
                                  textColor: AppTheme.primaryTeal,
                                  icon: Icons.repeat_rounded,
                                ),
                              ],
                              if (occ.isOverridden) ...[
                                const SizedBox(width: 6),
                                AppStatusBadge.warning('Diubah'),
                              ],
                              const Spacer(),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                        Icon(Icons.edit_calendar_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Ubah Hari Ini (WFH/dll)'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        Icon(Icons.event_busy_outlined, size: 18, color: AppTheme.danger),
                                        const SizedBox(width: 8),
                                        Text('Batalkan Hari Ini (Libur)', style: TextStyle(color: AppTheme.danger)),
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (occ.locationText != null && occ.locationText!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    occ.locationText!,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (occ.notes != null && occ.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              occ.notes!,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
