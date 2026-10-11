import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Membuka koneksi database SQLite lokal di background thread / isolate
LazyDatabase openDatabaseConnection({bool inMemory = false}) {
  return LazyDatabase(() async {
    if (inMemory) {
      return NativeDatabase.memory();
    }
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'anakkost.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
