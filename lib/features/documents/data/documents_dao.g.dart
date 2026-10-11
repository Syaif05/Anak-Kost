// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documents_dao.dart';

// ignore_for_file: type=lint
mixin _$DocumentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DocumentsTable get documents => attachedDatabase.documents;
  $AttachmentsTable get attachments => attachedDatabase.attachments;
  $AttachmentLinksTable get attachmentLinks => attachedDatabase.attachmentLinks;
  $ReminderRulesTable get reminderRules => attachedDatabase.reminderRules;
  DocumentsDaoManager get managers => DocumentsDaoManager(this);
}

class DocumentsDaoManager {
  final _$DocumentsDaoMixin _db;
  DocumentsDaoManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db.attachedDatabase, _db.documents);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db.attachedDatabase, _db.attachments);
  $$AttachmentLinksTableTableManager get attachmentLinks =>
      $$AttachmentLinksTableTableManager(
        _db.attachedDatabase,
        _db.attachmentLinks,
      );
  $$ReminderRulesTableTableManager get reminderRules =>
      $$ReminderRulesTableTableManager(_db.attachedDatabase, _db.reminderRules);
}
