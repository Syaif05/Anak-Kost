import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/agenda_providers.dart';

class AddEventSheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const AddEventSheet({super.key, this.initialDate});

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  String? _selectedCalendarId;
  bool _isWeekly = false;
  final Set<int> _selectedWeekdays = {1}; // 1 = Senin
  DateTime? _recurrenceEnd;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedWeekdays.add(_selectedDate.weekday);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCalendarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kalender terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(agendaRepositoryProvider);

      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final startLocal = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(startDateTime);
      final endLocal = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(endDateTime);

      final weekdaysStr = _isWeekly && _selectedWeekdays.isNotEmpty
          ? (_selectedWeekdays.toList()..sort()).join(',')
          : null;
      final recurrenceEndStr = _recurrenceEnd != null
          ? DateFormat('yyyy-MM-dd').format(_recurrenceEnd!)
          : null;

      await repo.createEvent(
        calendarId: _selectedCalendarId!,
        title: _titleController.text.trim(),
        startLocal: startLocal,
        endLocal: endLocal,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        locationText: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        recurrenceKind: _isWeekly ? 'weekly' : 'none',
        weekdays: weekdaysStr,
        recurrenceEnd: recurrenceEndStr,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agenda berhasil ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarsStreamProvider);
    final theme = Theme.of(context);

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
                    'Tambah Agenda Baru',
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
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Judul Agenda *',
                  hintText: 'Misal: Rapat Tim Magang / Kuliah Umum',
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              calendarsAsync.when(
                data: (calendars) {
                  if (calendars.isEmpty) {
                    return const Text('Tidak ada kalender tersedia');
                  }
                  _selectedCalendarId ??= calendars.first.id;
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCalendarId,
                    decoration: InputDecoration(
                      labelText: 'Kalender',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: calendars.map((cal) {
                      return DropdownMenuItem(
                        value: cal.id,
                        child: Text(cal.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCalendarId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text('Mulai: ${_startTime.format(context)}'),
                      onPressed: _pickStartTime,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_filled, size: 18),
                      label: Text('Selesai: ${_endTime.format(context)}'),
                      onPressed: _pickEndTime,
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
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Lokasi (Opsional)',
                  hintText: 'Misal: Gedung A Lt. 3 / Google Meet',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ulangi Tiap Minggu', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Agenda berulang mingguan (misal jadwal magang / kuliah)'),
                value: _isWeekly,
                onChanged: (val) => setState(() => _isWeekly = val),
              ),
              if (_isWeekly) ...[
                const SizedBox(height: 8),
                const Text('Pilih Hari Berulang:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (int day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(_weekdayName(day)),
                        selected: _selectedWeekdays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedWeekdays.add(day);
                            } else if (_selectedWeekdays.length > 1) {
                              _selectedWeekdays.remove(day);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
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
                    : const Text('Simpan Agenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayName(int day) {
    switch (day) {
      case 1:
        return 'Sen';
      case 2:
        return 'Sel';
      case 3:
        return 'Rab';
      case 4:
        return 'Kam';
      case 5:
        return 'Jum';
      case 6:
        return 'Sab';
      case 7:
        return 'Min';
      default:
        return '';
    }
  }
}
