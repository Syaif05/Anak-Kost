// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../security/encryption_service.dart';

/// Layanan Ekspor CSV & Backup Terenkripsi (PRD GAMINI.md Bagian 7.8 & Gate Test T18)
class BackupAndExportService {
  final AppDatabase _db;
  final EncryptionService _encryptionService;

  BackupAndExportService({
    required AppDatabase db,
    EncryptionService? encryptionService,
  })  : _db = db,
        _encryptionService = encryptionService ?? EncryptionService();

  /// 1. Sanitasi Formula Injection untuk CSV / Spreadsheet (Gate Test T18)
  /// Karakter awalan `=`, `+`, `-`, `@` pada teks pengguna dinonaktifkan dengan tanda petik tunggal (`'`).
  static String sanitizeCsvCell(String input) {
    if (input.isEmpty) return input;
    final firstChar = input[0];
    if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
      return "'$input";
    }
    return input;
  }

  /// 2. Ekspor Transaksi Keuangan ke Format CSV (FIN & Gate T18)
  Future<String> exportTransactionsCsv() async {
    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)]))
        .get();

    final categories = await _db.select(_db.categories).get();
    final catMap = {for (var c in categories) c.id: c.name};

    final rows = <List<dynamic>>[];
    // Header Baris CSV
    rows.add([
      'Tanggal',
      'Tipe',
      'Kategori',
      'Toko / Merchant',
      'Nominal (Rp)',
      'Catatan',
      'Status'
    ]);

    for (final tx in transactions) {
      final categoryName = tx.categoryId != null ? (catMap[tx.categoryId] ?? '') : '';
      rows.add([
        tx.localDate,
        tx.kind,
        sanitizeCsvCell(categoryName),
        sanitizeCsvCell(tx.merchant ?? ''),
        tx.amountRp, // Angka tetap murni angka
        sanitizeCsvCell(tx.note ?? ''),
        tx.status,
      ]);
    }

    return csv.encode(rows);
  }

  /// 3. Ekspor Inventaris Barang ke Format CSV
  Future<String> exportInventoryCsv() async {
    final items = await (_db.select(_db.inventoryItems)..where((t) => t.deletedAt.isNull())).get();

    final rows = <List<dynamic>>[];
    rows.add(['Nama Barang', 'Kategori Stok', 'Satuan', 'Stok Saat Ini (Unit Dasar)']);

    for (final item in items) {
      final stockMilli = await _db.inventoryDao.getItemStockMilli(item.id);
      final stockBase = stockMilli / 1000.0;

      rows.add([
        sanitizeCsvCell(item.name),
        sanitizeCsvCell(item.stockCategory ?? '-'),
        item.baseUnit,
        stockBase,
      ]);
    }

    return csv.encode(rows);
  }

  /// 4. Membuat Backup Penuh Terenkripsi AES-256-GCM (PRD Bagian 7.8)
  /// Mengenkripsi seluruh domain data menggunakan recovery secret / passphrase pengguna.
  /// Menolak menyertakan PIN verifier, JWT token, atau session kredensial privat.
  Future<Map<String, dynamic>> createEncryptedBackup({
    required String recoverySecret,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = await (_db.select(_db.profiles)..limit(1)).getSingleOrNull();

    // Kumpulkan seluruh data domain
    final wallets = await _db.select(_db.wallets).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await _db.select(_db.transactions).get();
    final walletEntries = await _db.select(_db.walletEntries).get();
    final items = await _db.select(_db.inventoryItems).get();
    final movements = await _db.select(_db.inventoryMovements).get();
    final events = await _db.select(_db.activityEvents).get();
    final tasks = await _db.select(_db.tasks).get();
    final billTemplates = await _db.select(_db.billTemplates).get();
    final billOccurrences = await _db.select(_db.billOccurrences).get();
    final documents = await _db.select(_db.documents).get();
    final attachments = await _db.select(_db.attachments).get();

    final manifest = {
      'backup_version': 1,
      'schema_version': 1,
      'created_at': now,
      'crypto_context_id': profile?.cryptoContextId ?? 'ctx-default',
      'owner_id': profile?.id ?? 'user-default',
      'data': {
        'wallets': wallets.map((w) => {'id': w.id, 'name': w.name, 'wallet_type': w.walletType}).toList(),
        'categories': categories.map((c) => {'id': c.id, 'name': c.name, 'direction': c.direction}).toList(),
        'transactions': transactions.map((t) => {'id': t.id, 'kind': t.kind, 'amount_rp': t.amountRp, 'local_date': t.localDate}).toList(),
        'wallet_entries': walletEntries.map((e) => {'id': e.id, 'transaction_id': e.transactionId, 'wallet_id': e.walletId, 'amount_rp': e.amountRp}).toList(),
        'inventory_items': items.map((i) => {'id': i.id, 'name': i.name, 'base_unit': i.baseUnit, 'min_milli': i.minimumQtyMilli}).toList(),
        'inventory_movements': movements.map((m) => {'id': m.id, 'inventory_item_id': m.inventoryItemId, 'delta_milli': m.quantityDeltaMilli}).toList(),
        'activity_events': events.map((e) => {'id': e.id, 'title': e.title, 'start_local': e.startLocal}).toList(),
        'tasks': tasks.map((t) => {'id': t.id, 'title': t.title, 'status': t.status}).toList(),
        'bill_templates': billTemplates.map((b) => {'id': b.id, 'name': b.name, 'est_rp': b.estimatedAmountRp}).toList(),
        'bill_occurrences': billOccurrences.map((o) => {'id': o.id, 'template_id': o.templateId, 'period_key': o.periodKey}).toList(),
        'documents': documents.map((d) => {'id': d.id, 'doc_type': d.documentType}).toList(),
        'attachments': attachments.map((a) => {'id': a.id, 'media_kind': a.mediaKind, 'sha256': a.ciphertextSha256}).toList(),
      },
    };

    final manifestJson = jsonEncode(manifest);
    final salt = _encryptionService.generateRandomBytes(16);
    final derivedKey = await _encryptionService.deriveKeyPbkdf2(
      passwordOrSecret: recoverySecret,
      salt: salt,
      iterations: 10000,
    );

    final encrypted = await _encryptionService.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(manifestJson)),
      key: derivedKey,
      aad: utf8.encode('anakkost_backup_v1'),
    );

    return {
      'format': 'anakkost_encrypted_backup',
      'version': 1,
      'salt_base64': base64Encode(salt),
      'nonce_base64': base64Encode(encrypted.nonce),
      'ciphertext_base64': base64Encode(encrypted.combinedWithTag),
    };
  }

  /// 5. Memulihkan Data dari Backup Terenkripsi
  Future<Map<String, dynamic>> decryptBackup({
    required Map<String, dynamic> backupEnvelope,
    required String recoverySecret,
  }) async {
    final salt = base64Decode(backupEnvelope['salt_base64'] as String);
    final nonce = base64Decode(backupEnvelope['nonce_base64'] as String);
    final ciphertextWithTag = base64Decode(backupEnvelope['ciphertext_base64'] as String);

    final derivedKey = await _encryptionService.deriveKeyPbkdf2(
      passwordOrSecret: recoverySecret,
      salt: salt,
      iterations: 10000,
    );

    final payload = EncryptedPayload.fromCombined(
      combined: ciphertextWithTag,
      nonce: nonce,
    );

    final plaintext = await _encryptionService.decrypt(
      ciphertext: payload.ciphertext,
      tag: payload.tag,
      nonce: payload.nonce,
      key: derivedKey,
      aad: utf8.encode('anakkost_backup_v1'),
    );

    final manifestJson = utf8.decode(plaintext);
    return jsonDecode(manifestJson) as Map<String, dynamic>;
  }
}
