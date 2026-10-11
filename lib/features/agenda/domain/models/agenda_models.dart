import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';

/// DTO Instance Acara / Occurrence Agenda Hasil Evaluasi Recurrence & Exception
class AgendaOccurrence {
  final String eventId;
  final String calendarId;
  final String title;
  final String? notes;
  final String? locationText;
  final DateTime start;
  final DateTime end;
  final String timezone;
  final String occurrenceKey;
  final bool isCancelled;
  final bool isOverridden;
  final bool isRecurring;

  const AgendaOccurrence({
    required this.eventId,
    required this.calendarId,
    required this.title,
    this.notes,
    this.locationText,
    required this.start,
    required this.end,
    required this.timezone,
    required this.occurrenceKey,
    this.isCancelled = false,
    this.isOverridden = false,
    this.isRecurring = false,
  });

  Duration get duration => end.difference(start);
}

/// DTO Tugas Lengkap beserta Checklist Subtugas & Status Terlambat Dinamis
class TaskWithSubtasks {
  final Task task;
  final List<TaskChecklistItem> checklist;

  const TaskWithSubtasks({
    required this.task,
    this.checklist = const [],
  });

  /// Status terlambat dihitung dinamis dari waktu sekarang (PRD Bagian 6.4)
  bool get isOverdue {
    if (task.status == 'done') return false;
    final now = DateTime.now();

    if (task.dueAt != null) {
      return now.millisecondsSinceEpoch > task.dueAt!;
    }

    if (task.dueLocalDate != null) {
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      return todayStr.compareTo(task.dueLocalDate!) > 0;
    }

    return false;
  }

  int get completedChecklistCount => checklist.where((c) => c.isDone).length;
  int get totalChecklistCount => checklist.length;
  double get checklistProgress =>
      totalChecklistCount > 0 ? (completedChecklistCount / totalChecklistCount) : 0.0;
}

/// Engine Evaluasi Recurrence Mingguan & Pengecualian Acara (Test T10)
class AgendaRecurrenceEngine {
  /// Menghitung seluruh kejadian acara dalam rentang tanggal lokal [rangeStart, rangeEnd]
  static List<AgendaOccurrence> evaluateOccurrences({
    required List<ActivityEvent> events,
    required List<ActivityEventException> exceptions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final occurrences = <AgendaOccurrence>[];

    // Peta pengecualian berdasarkan eventId + occurrenceKey
    final exceptionMap = <String, ActivityEventException>{};
    for (final exc in exceptions) {
      exceptionMap['${exc.eventId}_${exc.occurrenceKey}'] = exc;
    }

    for (final event in events) {
      final eventStart = DateTime.parse(event.startLocal);
      final eventEnd = DateTime.parse(event.endLocal);
      final duration = eventEnd.difference(eventStart);

      if (event.recurrenceKind == 'none') {
        // Sekali jalan
        if (eventEnd.isAfter(rangeStart) && eventStart.isBefore(rangeEnd)) {
          final occKey = DateFormat('yyyy-MM-ddTHH:mm:ss').format(eventStart);
          final exc = exceptionMap['${event.id}_$occKey'];

          if (exc != null && exc.action == 'cancel') {
            continue; // dibatalkan
          }

          occurrences.add(_buildOccurrence(
            event: event,
            start: eventStart,
            end: eventEnd,
            occKey: occKey,
            exception: exc,
          ));
        }
      } else if (event.recurrenceKind == 'weekly') {
        // Berulang mingguan berdasarkan daftar weekdays ISO (1=Senin ... 7=Minggu)
        final weekdaysList = _parseWeekdays(event.weekdays);
        final recurrenceEnd = event.recurrenceEnd != null
            ? DateTime.parse(event.recurrenceEnd!)
            : null;

        var currentDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
        final endDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

        while (!currentDay.isAfter(endDay)) {
          // Jangan evaluasi sebelum tanggal mulai acara
          final eventStartDateOnly = DateTime(eventStart.year, eventStart.month, eventStart.day);
          if (currentDay.isBefore(eventStartDateOnly)) {
            currentDay = currentDay.add(const Duration(days: 1));
            continue;
          }

          // Jangan evaluasi setelah recurrenceEnd jika ada
          if (recurrenceEnd != null && currentDay.isAfter(recurrenceEnd)) {
            break;
          }

          if (weekdaysList.contains(currentDay.weekday)) {
            // Jam mulai dan selesai mengambil jam dinding asli dari event
            final occStart = DateTime(
              currentDay.year,
              currentDay.month,
              currentDay.day,
              eventStart.hour,
              eventStart.minute,
              eventStart.second,
            );
            final occEnd = occStart.add(duration);

            final occKey = DateFormat('yyyy-MM-dd').format(currentDay);
            final exc = exceptionMap['${event.id}_$occKey'];

            // Test T10: Jika exception adalah 'cancel', batalkan kejadian pada tanggal ini
            if (exc != null && exc.action == 'cancel') {
              currentDay = currentDay.add(const Duration(days: 1));
              continue;
            }

            occurrences.add(_buildOccurrence(
              event: event,
              start: occStart,
              end: occEnd,
              occKey: occKey,
              exception: exc,
            ));
          }

          currentDay = currentDay.add(const Duration(days: 1));
        }
      }
    }

    // Urutkan berdasarkan waktu mulai
    occurrences.sort((a, b) => a.start.compareTo(b.start));
    return occurrences;
  }

  static AgendaOccurrence _buildOccurrence({
    required ActivityEvent event,
    required DateTime start,
    required DateTime end,
    required String occKey,
    ActivityEventException? exception,
  }) {
    if (exception != null && exception.action == 'override' && exception.overridePayload != null) {
      try {
        final payload = jsonDecode(exception.overridePayload!) as Map<String, dynamic>;
        final newTitle = payload['title'] as String? ?? event.title;
        final newNotes = payload['notes'] as String? ?? event.notes;
        final newLocation = payload['location_text'] as String? ?? event.locationText;
        final newStart = payload['start_local'] != null
            ? DateTime.parse(payload['start_local'] as String)
            : start;
        final newEnd = payload['end_local'] != null
            ? DateTime.parse(payload['end_local'] as String)
            : end;

        return AgendaOccurrence(
          eventId: event.id,
          calendarId: event.calendarId,
          title: newTitle,
          notes: newNotes,
          locationText: newLocation,
          start: newStart,
          end: newEnd,
          timezone: event.timezone,
          occurrenceKey: occKey,
          isOverridden: true,
          isRecurring: event.recurrenceKind != 'none',
        );
      } catch (_) {}
    }

    return AgendaOccurrence(
      eventId: event.id,
      calendarId: event.calendarId,
      title: event.title,
      notes: event.notes,
      locationText: event.locationText,
      start: start,
      end: end,
      timezone: event.timezone,
      occurrenceKey: occKey,
      isRecurring: event.recurrenceKind != 'none',
    );
  }

  static List<int> _parseWeekdays(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [1, 2, 3, 4, 5]; // Default hari kerja (Senin-Jumat)
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }
}
