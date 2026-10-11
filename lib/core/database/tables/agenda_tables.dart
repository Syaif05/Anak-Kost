import 'package:drift/drift.dart';
import 'common_columns.dart';

/// Kalender Kegiatan Fleksibel (GAMINI.md Bagian 6.4)
class ActivityCalendars extends Table with CommonDomainColumns {
  TextColumn get name => text()();
  TextColumn get kind => text()(); // internship, study, personal, custom
  TextColumn get colorKey => text().withDefault(const Constant('indigo'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

/// Acara / Agenda Kegiatan (GAMINI.md Bagian 6.4)
class ActivityEvents extends Table with CommonDomainColumns {
  TextColumn get calendarId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get locationText => text().nullable()();
  TextColumn get startLocal => text()(); // ISO local YYYY-MM-DDTHH:mm:ss
  TextColumn get endLocal => text()(); // ISO local YYYY-MM-DDTHH:mm:ss
  TextColumn get timezone => text().withDefault(const Constant('Asia/Jakarta'))();
  TextColumn get recurrenceKind => text().withDefault(const Constant('none'))(); // none, weekly
  TextColumn get weekdays => text().nullable()(); // CSV: "1,2,3,4,5"
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  TextColumn get recurrenceEnd => text().nullable()(); // YYYY-MM-DD
  TextColumn get seriesParentId => text().nullable()();
}

/// Pengecualian Agenda Berulang (GAMINI.md Bagian 6.4)
class ActivityEventExceptions extends Table with CommonDomainColumns {
  TextColumn get eventId => text()();
  TextColumn get occurrenceKey => text()();
  TextColumn get originalStartLocal => text()();
  TextColumn get action => text()(); // cancel, override
  TextColumn get overridePayload => text().nullable()(); // JSON
}

/// Tugas & Deadline (GAMINI.md Bagian 6.4)
class Tasks extends Table with CommonDomainColumns {
  TextColumn get calendarId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))(); // todo, doing, done
  TextColumn get priority => text().withDefault(const Constant('normal'))(); // low, normal, high
  IntColumn get dueAt => integer().nullable()(); // epoch millis UTC
  TextColumn get dueLocalDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get timezone => text().nullable()();
  IntColumn get completedAt => integer().nullable()(); // epoch millis UTC
}

/// Checklist Subtugas (GAMINI.md Bagian 6.4)
class TaskChecklistItems extends Table with CommonDomainColumns {
  TextColumn get taskId => text()();
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Catatan Cepat (GAMINI.md Bagian 6.4)
class QuickNotes extends Table with CommonDomainColumns {
  TextColumn get calendarId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get noteDate => text()(); // YYYY-MM-DD
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
}
