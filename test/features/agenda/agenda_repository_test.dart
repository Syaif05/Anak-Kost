import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;

import 'package:anakkost/core/database/app_database.dart';
import 'package:anakkost/core/notifications/notification_service.dart';
import 'package:anakkost/features/agenda/data/agenda_dao.dart';
import 'package:anakkost/features/agenda/data/agenda_repository.dart';
import 'package:anakkost/features/agenda/domain/models/agenda_models.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AgendaDao agendaDao;
  late AgendaRepository agendaRepo;
  late MockSecureStorage mockSecureStorage;
  late MockNotificationService mockNotificationService;

  setUp(() async {
    db = AppDatabase.inMemory();
    agendaDao = db.agendaDao;
    mockSecureStorage = MockSecureStorage();
    mockNotificationService = MockNotificationService();

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'mock-device-id');
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    when(() => mockNotificationService.generateId(any())).thenReturn(12345);
    when(() => mockNotificationService.scheduleNotification(
          id: any(named: 'id'),
          channelId: any(named: 'channelId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationService.cancelNotification(any())).thenAnswer((_) async {});

    agendaRepo = AgendaRepository(
      db: db,
      dao: agendaDao,
      notificationService: mockNotificationService,
      secureStorage: mockSecureStorage,
    );

    // Inisialisasi profil pengguna
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
            id: 'user-t10-001',
            cryptoContextId: 'crypto-ctx-001',
            displayName: const drift.Value('Anak Kost T10'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Agenda & Task Module Tests (Fase 3)', () {
    test('Gate Test T10: Agenda mingguan + libur + override kejadian; alarm notifikasi dibatalkan', () async {
      // 1. Buat Kalender Magang
      final calId = await agendaRepo.createCalendar(
        name: 'Magang Kerja',
        kind: 'internship',
        colorKey: 'blue',
      );
      expect(calId, isNotEmpty);

      // 2. Buat Agenda Mingguan: Senin (1) dan Rabu (3), jam 09:00 - 17:00
      // Tanggal mulai: Senin, 12 Oktober 2026
      final eventId = await agendaRepo.createEvent(
        calendarId: calId,
        title: 'Kerja di Kantor',
        startLocal: '2026-10-12T09:00:00',
        endLocal: '2026-10-12T17:00:00',
        locationText: 'Kantor Pusat',
        recurrenceKind: 'weekly',
        weekdays: '1,3', // Senin dan Rabu
        recurrenceEnd: '2026-10-31',
      );
      expect(eventId, isNotEmpty);

      // 3. Evaluasi Kejadian Minggu 1 (12 Okt 2026 s/d 18 Okt 2026)
      final rangeStart = DateTime(2026, 10, 12, 0, 0, 0);
      final rangeEnd = DateTime(2026, 10, 18, 23, 59, 59);

      var events = await agendaDao.watchEvents().first;
      var exceptions = await agendaDao.watchExceptionsForEvent(eventId).first;

      var occurrences = AgendaRecurrenceEngine.evaluateOccurrences(
        events: events,
        exceptions: exceptions,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // Harus ada 2 kejadian: Senin 12 Okt dan Rabu 14 Okt
      expect(occurrences, hasLength(2));
      expect(occurrences[0].occurrenceKey, '2026-10-12');
      expect(occurrences[0].title, 'Kerja di Kantor');
      expect(occurrences[0].start.weekday, DateTime.monday);
      expect(occurrences[1].occurrenceKey, '2026-10-14');
      expect(occurrences[1].title, 'Kerja di Kantor');
      expect(occurrences[1].start.weekday, DateTime.wednesday);

      // 4. Libur Nasional pada Senin 12 Okt -> Tambahkan Exception 'cancel'
      final cancelExcId = await agendaRepo.addEventException(
        eventId: eventId,
        occurrenceKey: '2026-10-12',
        originalStartLocal: '2026-10-12T09:00:00',
        action: 'cancel',
      );
      expect(cancelExcId, isNotEmpty);

      // Verifikasi notifikasi alarm dibatalkan (Test T10)
      verify(() => mockNotificationService.cancelNotification(any())).called(greaterThanOrEqualTo(1));

      // Evaluasi ulang: Senin 12 Okt harus hilang, Rabu 14 Okt tetap ada
      exceptions = await agendaDao.watchExceptionsForEvent(eventId).first;
      occurrences = AgendaRecurrenceEngine.evaluateOccurrences(
        events: events,
        exceptions: exceptions,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(occurrences, hasLength(1));
      expect(occurrences[0].occurrenceKey, '2026-10-14');
      expect(occurrences[0].title, 'Kerja di Kantor');

      // 5. Override Kejadian Rabu 14 Okt -> Bekerja dari Kost (WFH)
      final overrideExcId = await agendaRepo.addEventException(
        eventId: eventId,
        occurrenceKey: '2026-10-14',
        originalStartLocal: '2026-10-14T09:00:00',
        action: 'override',
        overridePayload: {
          'title': 'Magang WFH (Kost)',
          'location_text': 'Kamar Kost',
        },
      );
      expect(overrideExcId, isNotEmpty);

      // Evaluasi ulang: Kejadian Rabu berubah judul dan lokasi
      exceptions = await agendaDao.watchExceptionsForEvent(eventId).first;
      occurrences = AgendaRecurrenceEngine.evaluateOccurrences(
        events: events,
        exceptions: exceptions,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(occurrences, hasLength(1));
      expect(occurrences[0].occurrenceKey, '2026-10-14');
      expect(occurrences[0].title, 'Magang WFH (Kost)');
      expect(occurrences[0].locationText, 'Kamar Kost');
      expect(occurrences[0].isOverridden, isTrue);

      // 6. Verifikasi Sync Outbox mencatat 2 exceptions
      final outboxItems = await db.select(db.syncOutbox).get();
      final excOutbox = outboxItems.where((o) => o.aggregateType == 'event_exception').toList();
      expect(excOutbox, hasLength(2));
    });

    test('Task & Checklist: Progres checklist dan perhitungan dinamis overdue', () async {
      // 1. Buat Task dengan Checklist Subtugas
      final taskId = await agendaRepo.createTask(
        title: 'Laporan Mingguan Magang',
        description: 'Bab 1 s/d Bab 3',
        priority: 'high',
        dueLocalDate: '2026-10-10', // Kemarin (lewat deadline)
        dueAt: DateTime(2026, 10, 10, 18, 0).millisecondsSinceEpoch,
        checklistTitles: ['Drafting Bab 1', 'Revisi Mentor Bab 2', 'Finalisasi Bab 3'],
      );
      expect(taskId, isNotEmpty);

      // Ambil Task beserta Subtugasnya
      var tasks = await agendaDao.watchTasksWithSubtasks().first;
      expect(tasks, hasLength(1));

      var taskItem = tasks.first;
      expect(taskItem.task.title, 'Laporan Mingguan Magang');
      expect(taskItem.totalChecklistCount, 3);
      expect(taskItem.completedChecklistCount, 0);
      expect(taskItem.checklistProgress, 0.0);
      expect(taskItem.task.priority, 'high');
      expect(taskItem.isOverdue, isTrue); // Lewat tanggal 10 Okt dan belum selesai

      // 2. Selesaikan 1 checklist subtugas
      final firstChecklist = taskItem.checklist.first;
      await agendaRepo.toggleChecklistItem(firstChecklist.id, true);

      tasks = await agendaDao.watchTasksWithSubtasks().first;
      taskItem = tasks.first;
      expect(taskItem.completedChecklistCount, 1);
      expect(taskItem.checklistProgress, closeTo(0.333, 0.01));

      // 3. Ubah status task menjadi 'done'
      await agendaRepo.updateTaskStatus(taskId, 'done');

      tasks = await agendaDao.watchTasksWithSubtasks().first;
      taskItem = tasks.first;
      expect(taskItem.task.status, 'done');
      expect(taskItem.task.completedAt, isNotNull);
      // Ketika sudah 'done', tidak lagi dianggap overdue
      expect(taskItem.isOverdue, isFalse);
    });
  });
}
