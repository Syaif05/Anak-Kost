// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agenda_dao.dart';

// ignore_for_file: type=lint
mixin _$AgendaDaoMixin on DatabaseAccessor<AppDatabase> {
  $ActivityCalendarsTable get activityCalendars =>
      attachedDatabase.activityCalendars;
  $ActivityEventsTable get activityEvents => attachedDatabase.activityEvents;
  $ActivityEventExceptionsTable get activityEventExceptions =>
      attachedDatabase.activityEventExceptions;
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskChecklistItemsTable get taskChecklistItems =>
      attachedDatabase.taskChecklistItems;
  $QuickNotesTable get quickNotes => attachedDatabase.quickNotes;
  AgendaDaoManager get managers => AgendaDaoManager(this);
}

class AgendaDaoManager {
  final _$AgendaDaoMixin _db;
  AgendaDaoManager(this._db);
  $$ActivityCalendarsTableTableManager get activityCalendars =>
      $$ActivityCalendarsTableTableManager(
        _db.attachedDatabase,
        _db.activityCalendars,
      );
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(
        _db.attachedDatabase,
        _db.activityEvents,
      );
  $$ActivityEventExceptionsTableTableManager get activityEventExceptions =>
      $$ActivityEventExceptionsTableTableManager(
        _db.attachedDatabase,
        _db.activityEventExceptions,
      );
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskChecklistItemsTableTableManager get taskChecklistItems =>
      $$TaskChecklistItemsTableTableManager(
        _db.attachedDatabase,
        _db.taskChecklistItems,
      );
  $$QuickNotesTableTableManager get quickNotes =>
      $$QuickNotesTableTableManager(_db.attachedDatabase, _db.quickNotes);
}
