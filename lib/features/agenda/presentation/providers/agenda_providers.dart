import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/agenda_dao.dart';
import '../../data/agenda_repository.dart';
import '../../domain/models/agenda_models.dart';

/// Provider singleton untuk AgendaRepository
final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return AgendaRepository(db: db, notificationService: notif);
});

/// Provider DAO Agenda
final agendaDaoProvider = Provider<AgendaDao>((ref) {
  return ref.watch(agendaRepositoryProvider).dao;
});

/// Stream daftar kalender aktif
final calendarsStreamProvider = StreamProvider<List<ActivityCalendar>>((ref) {
  return ref.watch(agendaDaoProvider).watchCalendars();
});

/// Parameter filter untuk daftar tugas
class TaskFilterParams {
  final String? calendarId;
  final String? status; // 'todo', 'doing', 'done', null for all

  const TaskFilterParams({this.calendarId, this.status});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFilterParams &&
          runtimeType == other.runtimeType &&
          calendarId == other.calendarId &&
          status == other.status;

  @override
  int get hashCode => Object.hash(calendarId, status);
}

/// Stream daftar tugas beserta checklist subtugasnya
final tasksStreamProvider =
    StreamProvider.family<List<TaskWithSubtasks>, TaskFilterParams>((ref, params) {
  return ref.watch(agendaDaoProvider).watchTasksWithSubtasks(
        calendarId: params.calendarId,
        status: params.status,
      );
});

/// Parameter rentang tanggal untuk occurrence agenda
class DateRangeParams {
  final DateTime start;
  final DateTime end;

  const DateRangeParams({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRangeParams &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Future provider untuk kejadian acara terhitung dalam rentang tanggal
final agendaOccurrencesProvider =
    FutureProvider.family<List<AgendaOccurrence>, DateRangeParams>((ref, range) {
  return ref.watch(agendaDaoProvider).getOccurrencesForRange(range.start, range.end);
});

/// Stream catatan cepat
final quickNotesStreamProvider = StreamProvider<List<QuickNote>>((ref) {
  return ref.watch(agendaDaoProvider).watchQuickNotes();
});
