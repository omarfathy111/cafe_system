class CafeNote {
  const CafeNote({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final String text;
  final DateTime createdAt;

  factory CafeNote.fromMap(Map<String, Object?> row) => CafeNote(
    id: row['id'] as int,
    text: row['note_text'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
