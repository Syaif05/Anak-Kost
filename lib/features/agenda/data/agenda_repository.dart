import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import 'agenda_dao.dart';

class AgendaRepository {
  final AppDatabase _db;
  final AgendaDao _dao;
  final NotificationService _notificationService;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid = const Uuid();

  AgendaRepository({
    required AppDatabase db,
    AgendaDao? dao,
    NotificationService? notificationService,
    FlutterSecureStorage? secureStorage,
  })  : _db = db,
        _dao = dao ?? AgendaDao(db),
        _notificationService = notificationService ?? NotificationService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  AgendaDao get dao => _dao;

  Future<String> _getDeviceId() async {
    var id = await _secureStorage.read(key: AppConstants.secKeyDeviceId);
    if (id == null) {
      id = _uuid.v4();
      await _secureStorage.write(key: AppConstants.secKeyDeviceId, value: id);
    }
    return id;
  }

  Future<String> _getUserId() async {
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();
    return profile?.id ?? '00000000-0000-0000-0000-000000000001';
  }

  /// 1. Buat Kalender Baru
  Future<String> createCalendar({
    required String name,
    required String kind, // internship, study, personal, custom
    String colorKey = 'indigo',
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final calId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.activityCalendars).insert(
          ActivityCalendarsCompanion.insert(
            id: calId,
            userId: userId,
            name: name,
            kind: kind,
            colorKey: Value(colorKey),
            createdAt: now,
            updatedAt: now,
            lastOperationId: opId,
            originDeviceId: deviceId,
          ),
        );

    return calId;
  }

  /// 2. Buat Agenda / Acara (Event)
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required String startLocal, // YYYY-MM-DDTHH:mm:ss
    required String endLocal,
    String? notes,
    String? locationText,
    String timezone = 'Asia/Jakarta',
    String recurrenceKind = 'none', // none, weekly
    String? weekdays, // e.g. "1,3,5"
    int intervalCount = 1,
    String? recurrenceEnd,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final eventId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.activityEvents).insert(
            ActivityEventsCompanion.insert(
              id: eventId,
              userId: userId,
              calendarId: calendarId,
              title: title,
              notes: Value(notes),
              locationText: Value(locationText),
              startLocal: startLocal,
              endLocal: endLocal,
              timezone: Value(timezone),
              recurrenceKind: Value(recurrenceKind),
              weekdays: Value(weekdays),
              intervalCount: Value(intervalCount),
              recurrenceEnd: Value(recurrenceEnd),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'activity_event',
              aggregateId: eventId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'title': title,
                'calendar_id': calendarId,
                'start_local': startLocal,
                'end_local': endLocal,
                'recurrence_kind': recurrenceKind,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    // Jadwalkan notifikasi lokal jika agenda sekali jalan
    if (recurrenceKind == 'none') {
      try {
        final startDate = DateTime.parse(startLocal);
        final notifId = _notificationService.generateId(eventId);
        await _notificationService.scheduleNotification(
          id: notifId,
          channelId: NotificationService.channelAgenda,
          title: 'Agenda: $title',
          body: locationText != null ? 'Lokasi: $locationText' : 'Waktu: $startLocal',
          scheduledDate: startDate.subtract(const Duration(minutes: 15)),
        );
      } catch (_) {}
    }

    return eventId;
  }

  /// 3. Tambah Pengecualian Acara (Cancel atau Override) (Test T10)
  Future<String> addEventException({
    required String eventId,
    required String occurrenceKey,
    required String originalStartLocal,
    required String action, // cancel, override
    Map<String, dynamic>? overridePayload,
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final excId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final payloadJson = overridePayload != null ? jsonEncode(overridePayload) : null;

    await _db.transaction(() async {
      await _db.into(_db.activityEventExceptions).insert(
            ActivityEventExceptionsCompanion.insert(
              id: excId,
              userId: userId,
              eventId: eventId,
              occurrenceKey: occurrenceKey,
              originalStartLocal: originalStartLocal,
              action: action,
              overridePayload: Value(payloadJson),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'event_exception',
              aggregateId: excId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'event_id': eventId,
                'occurrence_key': occurrenceKey,
                'action': action,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    // Jika dibatalkan, batalkan alarm notifikasi terkait (Test T10)
    final notifId = _notificationService.generateId('${eventId}_$occurrenceKey');
    await _notificationService.cancelNotification(notifId);

    return excId;
  }

  /// 4. Buat Tugas (Task)
  Future<String> createTask({
    required String title,
    String? description,
    String? calendarId,
    String? eventId,
    String priority = 'normal', // low, normal, high
    int? dueAt, // epoch millis
    String? dueLocalDate, // YYYY-MM-DD
    List<String> checklistTitles = const [],
  }) async {
    final userId = await _getUserId();
    final deviceId = await _getDeviceId();
    final taskId = _uuid.v4();
    final opId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.tasks).insert(
            TasksCompanion.insert(
              id: taskId,
              userId: userId,
              calendarId: Value(calendarId),
              eventId: Value(eventId),
              title: title,
              description: Value(description),
              status: const Value('todo'),
              priority: Value(priority),
              dueAt: Value(dueAt),
              dueLocalDate: Value(dueLocalDate),
              createdAt: now,
              updatedAt: now,
              lastOperationId: opId,
              originDeviceId: deviceId,
            ),
          );

      // Simpan checklist subtugas
      for (var i = 0; i < checklistTitles.length; i++) {
        await _db.into(_db.taskChecklistItems).insert(
              TaskChecklistItemsCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                taskId: taskId,
                title: checklistTitles[i],
                sortOrder: Value(i),
                createdAt: now,
                updatedAt: now,
                lastOperationId: opId,
                originDeviceId: deviceId,
              ),
            );
      }

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              operationId: opId,
              aggregateType: 'task',
              aggregateId: taskId,
              baseVersion: 0,
              payloadJson: jsonEncode({
                'title': title,
                'priority': priority,
                'due_at': dueAt,
              }),
              localRevision: 1,
              createdAt: now,
            ),
          );
    });

    // Jadwalkan notifikasi deadline tugas jika ada dueAt
    if (dueAt != null) {
      try {
        final notifId = _notificationService.generateId(taskId);
        final dueDate = DateTime.fromMillisecondsSinceEpoch(dueAt);
        await _notificationService.scheduleNotification(
          id: notifId,
          channelId: NotificationService.channelTasks,
          title: 'Tenggat Tugas: $title',
          body: 'Prioritas: ${priority.toUpperCase()}',
          scheduledDate: dueDate.subtract(const Duration(hours: 1)),
        );
      } catch (_) {}
    }

    return taskId;
  }

  /// 5. Ubah Status Tugas (todo, doing, done)
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opId = _uuid.v4();

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: Value(newStatus),
        completedAt: Value(newStatus == 'done' ? now : null),
        updatedAt: Value(now),
        lastOperationId: Value(opId),
      ),
    );

    // Jika selesai, batalkan notifikasi deadline tugas
    if (newStatus == 'done') {
      final notifId = _notificationService.generateId(taskId);
      await _notificationService.cancelNotification(notifId);
    }
  }

  /// 6. Toggle Checklist Subtugas
  Future<void> toggleChecklistItem(String itemId, bool isDone) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.taskChecklistItems)..where((t) => t.id.equals(itemId))).write(
      TaskChecklistItemsCompanion(
        isDone: Value(isDone),
        updatedAt: Value(now),
      ),
    );
  }

  /// 7. Inisialisasi Kalender Default Jika Kosong
  Future<void> seedDefaultCalendarsIfEmpty() async {
    final existing = await (_db.select(_db.activityCalendars)..where((t) => t.deletedAt.isNull())).get();
    if (existing.isEmpty) {
      await createCalendar(name: 'Jadwal Magang', kind: 'internship', colorKey: 'blue');
      await createCalendar(name: 'Kuliah & Kampus', kind: 'study', colorKey: 'purple');
      await createCalendar(name: 'Pribadi & Kost', kind: 'personal', colorKey: 'teal');
    }
  }
}
