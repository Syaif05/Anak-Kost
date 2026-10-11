import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/bills_documents_tables.dart';
import '../domain/models/document_models.dart';

part 'documents_dao.g.dart';

@DriftAccessor(tables: [
  Documents,
  Attachments,
  AttachmentLinks,
  ReminderRules,
])
class DocumentsDao extends DatabaseAccessor<AppDatabase> with _$DocumentsDaoMixin {
  DocumentsDao(super.db);

  /// Stream daftar dokumen brankas
  Stream<List<DocumentWithDetails>> watchDocuments({String? documentType}) {
    final query = select(documents)..where((t) => t.deletedAt.isNull());
    if (documentType != null) {
      query.where((t) => t.documentType.equals(documentType));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

    return query.watch().asyncMap((docList) async {
      final result = <DocumentWithDetails>[];
      for (final doc in docList) {
        final attachments = await getAttachmentsForDocument(doc.id);
        result.add(DocumentWithDetails(document: doc, attachments: attachments));
      }
      return result;
    });
  }

  /// Mengambil single dokumen berdasarkan ID
  Future<DocumentWithDetails?> getDocument(String id) async {
    final doc = await (select(documents)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (doc == null) return null;

    final attachments = await getAttachmentsForDocument(id);
    return DocumentWithDetails(document: doc, attachments: attachments);
  }

  /// Mengambil lampiran berkas terkait dokumen melalui tabel attachment_links
  Future<List<Attachment>> getAttachmentsForDocument(String documentId) async {
    final links = await (select(attachmentLinks)
          ..where((l) => l.documentId.equals(documentId) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]))
        .get();

    final attachmentIds = links.map((l) => l.attachmentId).toList();
    if (attachmentIds.isEmpty) return [];

    return (select(attachments)
          ..where((a) => a.id.isIn(attachmentIds) & a.deletedAt.isNull()))
        .get();
  }
}
