/// Definisi Enum Domain Lengkap sesuai skema PostgreSQL & Drift di GAMINI.md Bagian 6
enum WalletType {
  cash,
  bank,
  ewallet,
  other;

  String get dbValue => name;
  static WalletType fromDb(String value) => WalletType.values.byName(value);
}

enum TransactionKind {
  income,
  expense,
  transfer,
  opening,
  adjustment,
  refund;

  String get dbValue => name;
  static TransactionKind fromDb(String value) => TransactionKind.values.byName(value);
}

enum TransactionStatus {
  posted,
  voided;

  String get dbValue => this == voided ? 'void' : 'posted';
  static TransactionStatus fromDb(String value) =>
      value == 'void' ? TransactionStatus.voided : TransactionStatus.posted;
}

enum EntryRole {
  main,
  source,
  destination,
  fee;

  String get dbValue => name;
  static EntryRole fromDb(String value) => EntryRole.values.byName(value);
}

enum MovementType {
  opening,
  add,
  use,
  adjust,
  reversal;

  String get dbValue => name;
  static MovementType fromDb(String value) => MovementType.values.byName(value);
}

enum ShoppingListStatus {
  open,
  completed,
  archived;

  String get dbValue => name;
  static ShoppingListStatus fromDb(String value) => ShoppingListStatus.values.byName(value);
}

enum ShoppingItemStatus {
  pending,
  bought,
  skipped;

  String get dbValue => name;
  static ShoppingItemStatus fromDb(String value) => ShoppingItemStatus.values.byName(value);
}

enum ActivityCalendarKind {
  internship,
  study,
  personal,
  custom;

  String get dbValue => name;
  static ActivityCalendarKind fromDb(String value) => ActivityCalendarKind.values.byName(value);
}

enum EventRecurrenceKind {
  none,
  weekly;

  String get dbValue => name;
  static EventRecurrenceKind fromDb(String value) => EventRecurrenceKind.values.byName(value);
}

enum ExceptionAction {
  cancel,
  override;

  String get dbValue => name;
  static ExceptionAction fromDb(String value) => ExceptionAction.values.byName(value);
}

enum TaskStatus {
  todo,
  doing,
  done;

  String get dbValue => name;
  static TaskStatus fromDb(String value) => TaskStatus.values.byName(value);
}

enum TaskPriority {
  low,
  normal,
  high;

  String get dbValue => name;
  static TaskPriority fromDb(String value) => TaskPriority.values.byName(value);
}

enum BillFrequency {
  once,
  weekly,
  monthly,
  yearly;

  String get dbValue => name;
  static BillFrequency fromDb(String value) => BillFrequency.values.byName(value);
}

enum DocumentType {
  ktp('ktp'),
  ktm('ktm'),
  internshipLetter('internship_letter'),
  leaseContract('lease_contract'),
  other('other');

  final String dbValue;
  const DocumentType(this.dbValue);

  static DocumentType fromDb(String value) =>
      DocumentType.values.firstWhere((e) => e.dbValue == value, orElse: () => DocumentType.other);
}

enum MediaKind {
  photo,
  scan,
  pdf,
  thumbnail;

  String get dbValue => name;
  static MediaKind fromDb(String value) => MediaKind.values.byName(value);
}

enum AttachmentRemoteState {
  pending,
  available,
  failed;

  String get dbValue => name;
  static AttachmentRemoteState fromDb(String value) => AttachmentRemoteState.values.byName(value);
}

enum AttachmentLinkRole {
  evidence,
  primary,
  page,
  thumbnail;

  String get dbValue => name;
  static AttachmentLinkRole fromDb(String value) => AttachmentLinkRole.values.byName(value);
}

enum SyncOutboxStatus {
  pending,
  inflight,
  conflict,
  blocked,
  done;

  String get dbValue => name;
  static SyncOutboxStatus fromDb(String value) => SyncOutboxStatus.values.byName(value);
}
