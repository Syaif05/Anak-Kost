import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/agenda_tables.dart';
import '../domain/models/agenda_models.dart';

part 'agenda_dao.g.dart';

@DriftAccessor(tables: [
  ActivityCalendars,
  ActivityEvents,
  ActivityEventExceptions,
  Tasks,
  TaskChecklistItems,
  QuickNotes,
])
class AgendaDao extends DatabaseAccessor<AppDatabase> with _$AgendaDaoMixin {
  AgendaDao(super.db);

  /// Stream daftar kalender aktif
  Stream<List<ActivityCalendar>> watchCalendars() {
    return (select(activityCalendars)
          ..where((t) => t.isArchived.equals(false) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Stream seluruh tugas dengan checklist subtugasnya
  Stream<List<TaskWithSubtasks>> watchTasksWithSubtasks({String? calendarId, String? status}) {
    final query = select(tasks)..where((t) => t.deletedAt.isNull());
    if (calendarId != null) {
      query.where((t) => t.calendarId.equals(calendarId));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.status, mode: OrderingMode.desc), // todo/doing before done
      (t) => OrderingTerm(expression: t.dueAt, mode: OrderingMode.asc),
    ]);

    return query.watch().asyncMap((taskList) async {
      final result = <TaskWithSubtasks>[];
      for (final t in taskList) {
        final subtasks = await (select(taskChecklistItems)
              ..where((c) => c.taskId.equals(t.id) & c.deletedAt.isNull())
              ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
            .get();
        result.add(TaskWithSubtasks(task: t, checklist: subtasks));
      }
      return result;
    });
  }

  /// Stream daftar event aktif
  Stream<List<ActivityEvent>> watchEvents({String? calendarId}) {
    final query = select(activityEvents)..where((t) => t.deletedAt.isNull());
    if (calendarId != null) {
      query.where((t) => t.calendarId.equals(calendarId));
    }
    return query.watch();
  }

  /// Stream daftar pengecualian untuk suatu event
  Stream<List<ActivityEventException>> watchExceptionsForEvent(String eventId) {
    return (select(activityEventExceptions)
          ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull()))
        .watch();
  }

  /// Mengambil occurrence agenda terhitung untuk rentang waktu tertentu
  Future<List<AgendaOccurrence>> getOccurrencesForRange(DateTime rangeStart, DateTime rangeEnd) async {
    final events = await (select(activityEvents)..where((t) => t.deletedAt.isNull())).get();
    final exceptions = await (select(activityEventExceptions)..where((t) => t.deletedAt.isNull())).get();

    return AgendaRecurrenceEngine.evaluateOccurrences(
      events: events,
      exceptions: exceptions,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  /// Stream occurrence agenda terhitung untuk rentang waktu tertentu
  Stream<List<AgendaOccurrence>> watchOccurrencesForRange(DateTime rangeStart, DateTime rangeEnd) {
    return select(activityEvents).watch().asyncMap((_) async {
      return getOccurrencesForRange(rangeStart, rangeEnd);
    });
  }

  /// Stream catatan cepat
  Stream<List<QuickNote>> watchQuickNotes() {
    return (select(quickNotes)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.noteDate, mode: OrderingMode.desc),
          ]))
        .watch();
  }
}
